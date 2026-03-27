//
// RemoteBrowserEngine.swift
//
// Copyright (c) 2025 Shawn Baek
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation
import HeadlessBrowserCore

/// A BrowserEngine that communicates with a remote browser
/// (Chrome headless, Chromium, Lightpanda) over WebSocket using the Chrome DevTools Protocol.
///
/// Provides full JavaScript execution on any platform (macOS, Linux)
/// without requiring WKWebView or system WebKit packages.
public final class RemoteBrowserEngine: BrowserEngine, @unchecked Sendable {

    // MARK: - Properties

    private let connection: RemoteBrowserConnection
    private let waitStrategy: PageLoadStrategy
    private let _userAgent: UserAgent
    private let _timeoutInSeconds: TimeInterval
    private var currentData: Data?
    private var currentURL: URL?
    private var domainsEnabled: Bool = false

    // Network idle tracking
    private var inflightRequests: Int = 0

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    // MARK: - Configuration

    /// Configuration for creating a RemoteBrowserEngine.
    public struct Configuration: Sendable {
        /// WebSocket URL of an already-running remote browser endpoint.
        public var webSocketURL: URL

        /// User agent override.
        public var userAgent: UserAgent

        /// Timeout for operations.
        public var timeoutInSeconds: TimeInterval

        /// Strategy for waiting for page loads.
        public var waitStrategy: PageLoadStrategy

        public init(
            webSocketURL: URL,
            userAgent: UserAgent = .chromeMac,
            timeoutInSeconds: TimeInterval = 30.0,
            waitStrategy: PageLoadStrategy = .load
        ) {
            self.webSocketURL = webSocketURL
            self.userAgent = userAgent
            self.timeoutInSeconds = timeoutInSeconds
            self.waitStrategy = waitStrategy
        }
    }

    // MARK: - Initialization

    /// Create a RemoteBrowserEngine with a configuration.
    public init(configuration: Configuration) async throws {
        self._userAgent = configuration.userAgent
        self._timeoutInSeconds = configuration.timeoutInSeconds
        self.waitStrategy = configuration.waitStrategy
        self.connection = RemoteBrowserConnection()

        try await connection.connect(to: configuration.webSocketURL)
        try await enableDomains()
    }

    /// Create a RemoteBrowserEngine with an existing connection (for testing).
    public init(
        connection: RemoteBrowserConnection,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0,
        waitStrategy: PageLoadStrategy = .load
    ) {
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds
        self.waitStrategy = waitStrategy
        self.connection = connection
    }

    // MARK: - Domain Setup

    private func enableDomains() async throws {
        guard !domainsEnabled else { return }

        // Enable Page domain for navigation events
        _ = try await connection.send(method: "Page.enable", timeout: _timeoutInSeconds)

        // Enable Network domain for network idle detection
        _ = try await connection.send(method: "Network.enable", timeout: _timeoutInSeconds)

        // Enable Runtime domain
        _ = try await connection.send(method: "Runtime.enable", timeout: _timeoutInSeconds)

        // Set user agent override
        _ = try await connection.send(
            method: "Network.setUserAgentOverride",
            params: ["userAgent": _userAgent.rawValue],
            timeout: _timeoutInSeconds
        )

        // Track network requests for idle detection
        connection.on("Network.requestWillBeSent") { [weak self] _ in
            self?.inflightRequests += 1
        }
        connection.on("Network.loadingFinished") { [weak self] _ in
            self?.inflightRequests = max(0, (self?.inflightRequests ?? 1) - 1)
        }
        connection.on("Network.loadingFailed") { [weak self] _ in
            self?.inflightRequests = max(0, (self?.inflightRequests ?? 1) - 1)
        }

        domainsEnabled = true
    }

    // MARK: - BrowserEngine Protocol

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        // Register event waiters BEFORE navigating to avoid race condition
        let loadWaiter = connection.expectEvent("Page.loadEventFired")

        // Navigate to the URL
        let response = try await connection.send(
            method: "Page.navigate",
            params: ["url": url.absoluteString],
            timeout: _timeoutInSeconds
        )

        // Check for navigation error (but not empty errorText — Chrome sometimes returns "" on success)
        if let result = response.result,
           let errorText = result["errorText"] as? String,
           !errorText.isEmpty {
            throw RemoteBrowserError.navigationFailed(errorText)
        }

        // Wait for page to be ready (non-fatal on timeout — page may be partially rendered)
        do {
            try await waitForPageReady(loadWaiter: loadWaiter)
        } catch {
            // Timeout waiting for load event — continue with whatever is rendered
        }

        // Handle PostAction
        try await handlePostAction(postAction)

        // Get the rendered HTML (use generous timeout for eval even if page load timed out)
        let html = try await getRenderedHTML()
        let data = html.data(using: .utf8) ?? Data()

        self.currentData = data
        self.currentURL = url

        return (data, url)
    }

    public func execute(_ script: String) async throws -> String {
        let response = try await connection.send(
            method: "Runtime.evaluate",
            params: [
                "expression": script,
                "returnByValue": true,
                "awaitPromise": true
            ],
            timeout: _timeoutInSeconds
        )

        return extractJSResult(from: response)
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        // Register event waiter BEFORE executing script that may navigate
        let loadWaiter = connection.expectEvent("Page.loadEventFired")

        // Execute the script (which may cause navigation)
        _ = try await connection.send(
            method: "Runtime.evaluate",
            params: [
                "expression": script,
                "returnByValue": true,
                "awaitPromise": true
            ],
            timeout: _timeoutInSeconds
        )

        // Wait for any triggered navigation
        try await waitForPageReady(loadWaiter: loadWaiter)
        try await handlePostAction(postAction)

        // Get rendered HTML
        let html = try await getRenderedHTML()
        let data = html.data(using: .utf8) ?? Data()

        // Update current URL from browser
        let urlResult = try await connection.send(
            method: "Runtime.evaluate",
            params: [
                "expression": "window.location.href",
                "returnByValue": true
            ],
            timeout: _timeoutInSeconds
        )
        let urlString = extractJSResult(from: urlResult)
        let newURL = URL(string: urlString)

        self.currentData = data
        self.currentURL = newURL ?? currentURL

        return (data, self.currentURL)
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else {
            // Try to get current content from the browser
            let html = try await getRenderedHTML()
            let data = html.data(using: .utf8) ?? Data()
            return (data, currentURL)
        }
        return (data, currentURL)
    }

    // MARK: - Wait Strategies

    private func waitForPageReady(loadWaiter: RemoteBrowserConnection.EventWaiter) async throws {
        switch waitStrategy {
        case .load:
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
        case .domContentLoaded:
            // For domContentLoaded we still use the load waiter as a fallback
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
        case .networkIdle(let idleTime):
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
            try await waitForNetworkIdle(idleTime: idleTime)
        case .selector(let selector):
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
            try await waitForSelector(selector)
        case .jsCondition(let condition):
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
            try await waitForJSCondition(condition)
        case .loadAndNetworkIdle(let idleTime):
            try await loadWaiter.wait(timeout: _timeoutInSeconds)
            try await waitForNetworkIdle(idleTime: idleTime)
        }
    }

    private func waitForNetworkIdle(idleTime: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(_timeoutInSeconds)
        var idleStart = Date()

        while Date() < deadline {
            if inflightRequests == 0 {
                if Date().timeIntervalSince(idleStart) >= idleTime {
                    return
                }
            } else {
                idleStart = Date()
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms poll
        }
    }

    private func waitForSelector(_ selector: String) async throws {
        let deadline = Date().addingTimeInterval(_timeoutInSeconds)
        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
        let script = "document.querySelector('\(escapedSelector)') !== null"

        while Date() < deadline {
            let result = try await execute(script)
            if result == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms poll
        }

        throw RemoteBrowserError.timeout("Timed out waiting for selector: \(selector)")
    }

    private func waitForJSCondition(_ condition: String) async throws {
        let deadline = Date().addingTimeInterval(_timeoutInSeconds)

        while Date() < deadline {
            let result = try await execute(condition)
            if result == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        throw RemoteBrowserError.timeout("Timed out waiting for JS condition: \(condition)")
    }

    // MARK: - PostAction Handling

    private func handlePostAction(_ postAction: PostAction) async throws {
        switch postAction {
        case .wait(let time):
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        case .validate(let condition):
            try await waitForJSCondition(condition)
        case .none:
            break
        }
    }

    // MARK: - HTML Retrieval

    private func getRenderedHTML() async throws -> String {
        let response = try await connection.send(
            method: "Runtime.evaluate",
            params: [
                "expression": "document.documentElement.outerHTML",
                "returnByValue": true
            ],
            timeout: max(_timeoutInSeconds, 30.0)
        )
        return extractJSResult(from: response)
    }

    // MARK: - Result Extraction

    private func extractJSResult(from response: BrowserResponse) -> String {
        guard let result = response.result,
              let remoteObject = result["result"] as? [String: Any] else {
            return ""
        }

        // Check for exceptions
        if let exceptionDetails = result["exceptionDetails"] as? [String: Any],
           let exception = exceptionDetails["exception"] as? [String: Any],
           let description = exception["description"] as? String {
            return "Error: \(description)"
        }

        // Extract value based on type
        if let value = remoteObject["value"] {
            if let stringValue = value as? String {
                return stringValue
            } else if let boolValue = value as? Bool {
                return boolValue ? "true" : "false"
            } else if let intValue = value as? Int {
                return String(intValue)
            } else if let doubleValue = value as? Double {
                return String(doubleValue)
            } else {
                return String(describing: value)
            }
        }

        // Fallback to description
        if let description = remoteObject["description"] as? String {
            return description
        }

        return ""
    }

    // MARK: - Cleanup

    /// Disconnect from the remote browser.
    public func disconnect() async {
        await connection.disconnect()
    }
}
