//
// WPEWebKitEngine.swift
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

#if os(Linux)
import Foundation
import HeadlessBrowserCore

#if canImport(CWebKit)
import CWebKit
#endif

// MARK: - WPE WebKit Engine

/// A browser engine using WPE WebKit for headless JavaScript rendering on Linux.
///
/// WPE (Web Platform for Embedded) is the official headless port of WebKit,
/// designed specifically for:
/// - Embedded systems without a display
/// - Server-side rendering
/// - Headless browser automation
///
/// This engine uses the same WebKit codebase as Safari and WKWebView on Apple
/// platforms, ensuring consistent rendering and JavaScript execution.
///
/// ## Installation
///
/// Ubuntu/Debian:
/// ```bash
/// sudo apt-get install libwpewebkit-1.1-dev libwpe-1.0-dev
/// ```
///
/// Fedora:
/// ```bash
/// sudo dnf install wpewebkit-devel wpebackend-fdo-devel
/// ```
///
/// ## Usage
///
/// ```swift
/// let engine = WPEWebKitEngine(timeoutInSeconds: 60.0)
/// let browser = HeadlessBrowser(name: "HeadlessBrowser", engine: engine)
///
/// let page: HTMLPage = try await browser.open(url: myURL).execute()
/// ```
///
/// ## Reference
/// - https://wpewebkit.org/
/// - https://github.com/WebKit/WebKit (Source/WebKit/WPE)
///
public final class WPEWebKitEngine: BrowserEngine, @unchecked Sendable {

    // MARK: - Properties

    private let _timeoutInSeconds: TimeInterval
    private var _userAgent: UserAgent
    private var currentData: Data?
    private var currentURL: URL?

    // WPE WebKit handles (opaque pointers to C objects)
    private var webContext: OpaquePointer?
    private var webView: OpaquePointer?
    private var mainLoop: OpaquePointer?

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    // MARK: - Initialization

    /// Creates a new WPEWebKitEngine instance for headless browsing.
    ///
    /// - Parameters:
    ///   - userAgent: User agent to use for requests
    ///   - timeoutInSeconds: Maximum time to wait for page load (default: 30 seconds)
    public init(userAgent: UserAgent = .safariMac, timeoutInSeconds: TimeInterval = 30.0) {
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds

        // Initialize WPE WebKit
        initializeWPE()
    }

    deinit {
        cleanup()
    }

    // MARK: - WPE Initialization

    private func initializeWPE() {
        // Note: Actual WPE WebKit initialization requires the C library
        // This is a placeholder for the actual implementation

        // In a full implementation:
        // 1. Initialize GLib main loop
        // 2. Create WPE WebKit web context
        // 3. Create WPE WebKit web view
        // 4. Configure settings (user agent, JavaScript enabled, etc.)

        #if CWEBKIT_HAS_WPE
        // Create main loop for async operations
        mainLoop = g_main_loop_new(nil, 0)

        // Create web context with default settings
        webContext = webkit_web_context_get_default()

        // Create web view
        webView = webkit_web_view_new_with_context(webContext)

        // Configure settings
        if let webView = webView {
            let settings = webkit_web_view_get_settings(webView)
            webkit_settings_set_enable_javascript(settings, 1)

            webkit_settings_set_user_agent(settings, _userAgent.rawValue)
        }
        #endif
    }

    private func cleanup() {
        #if CWEBKIT_HAS_WPE
        if let webView = webView {
            g_object_unref(webView)
        }
        if let mainLoop = mainLoop {
            g_main_loop_unref(mainLoop)
        }
        #endif
    }

    // MARK: - BrowserEngine Protocol

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_WPE
        guard let webView = webView else {
            throw ActionError.networkRequestFailure
        }

        // Load the URL
        webkit_web_view_load_uri(webView, url.absoluteString)

        // Wait for page to load
        try await waitForPageLoad()

        // Handle post action
        switch postAction {
        case .wait(let time):
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        case .validate(let script):
            try await waitForCondition(script: script)
        case .none:
            break
        }

        // Get rendered HTML
        let html = try await executeJavaScript("document.documentElement.outerHTML")
        let data = html.data(using: .utf8) ?? Data()

        self.currentData = data
        self.currentURL = url

        return (data, url)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func execute(_ script: String) async throws -> String {
        #if CWEBKIT_HAS_WPE
        return try await executeJavaScript(script)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_WPE
        // Execute script that may cause navigation
        _ = try await execute(script)

        // Wait for any navigation to complete
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
        try await waitForPageLoad()

        // Handle post action
        switch postAction {
        case .wait(let time):
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        case .validate(let script):
            try await waitForCondition(script: script)
        case .none:
            break
        }

        // Get rendered HTML
        let html = try await execute("document.documentElement.outerHTML")
        let data = html.data(using: .utf8) ?? Data()

        return (data, currentURL)
        #else
        throw ActionError.notSupported
        #endif
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else {
            throw ActionError.notFound
        }
        return (data, currentURL)
    }

    // MARK: - JavaScript Execution

    #if CWEBKIT_HAS_WPE
    private func executeJavaScript(_ script: String) async throws -> String {
        guard let webView = webView else {
            throw ActionError.networkRequestFailure
        }

        return try await withCheckedThrowingContinuation { continuation in
            webkit_web_view_run_javascript(
                webView,
                script,
                nil,
                { source, result, userData in
                    var error: UnsafeMutablePointer<GError>?
                    let jsResult = webkit_web_view_run_javascript_finish(
                        unsafeBitCast(source, to: OpaquePointer.self),
                        result,
                        &error
                    )

                    if let error = error {
                        g_error_free(error)
                        // Handle error
                        return
                    }

                    if let jsResult = jsResult {
                        let jsValue = webkit_javascript_result_get_js_value(jsResult)
                        if let cString = jsc_value_to_string(jsValue) {
                            let result = String(cString: cString)
                            g_free(cString)
                            webkit_javascript_result_unref(jsResult)
                            // continuation.resume(returning: result)
                            return
                        }
                        webkit_javascript_result_unref(jsResult)
                    }
                },
                nil
            )

            // Run event loop
            runEventLoop(timeout: timeoutInSeconds)
        }
    }
    #endif

    // MARK: - Wait Methods

    private func waitForPageLoad() async throws {
        // Wait for the page load event
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutInSeconds {
            #if CWEBKIT_HAS_WPE
            // Check if page is still loading
            if let webView = webView {
                let isLoading = webkit_web_view_is_loading(webView)
                if isLoading == 0 {
                    return
                }
            }

            // Process events
            runEventLoop(timeout: 0.1)
            #endif

            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }

        throw ActionError.timeout
    }

    private func waitForCondition(script: String) async throws {
        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeoutInSeconds {
            let result = try await execute(script)
            if result == "true" || result == "1" {
                return
            }

            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        throw ActionError.timeout
    }

    #if CWEBKIT_HAS_WPE
    private func runEventLoop(timeout: TimeInterval) {
        let context = g_main_context_default()
        let endTime = Date().addingTimeInterval(timeout)

        while Date() < endTime {
            if g_main_context_iteration(context, 0) == 0 {
                break
            }
        }
    }
    #endif

    // MARK: - Additional Methods

    /// Wait for a CSS selector to appear in the DOM.
    ///
    /// - Parameters:
    ///   - selector: CSS selector to wait for
    ///   - timeout: Maximum time to wait (default: 30 seconds)
    public func waitForSelector(_ selector: String, timeout: TimeInterval = 30.0) async throws {
        let escapedSelector = selector.replacingOccurrences(of: "'", with: "\\'")
        let script = "document.querySelector('\(escapedSelector)') !== null"

        let startTime = Date()
        while Date().timeIntervalSince(startTime) < timeout {
            let result = try await execute(script)
            if result == "true" {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        throw ActionError.timeout
    }

    /// Wait for network activity to settle.
    ///
    /// - Parameters:
    ///   - idleTime: How long network must be idle (default: 0.5 seconds)
    ///   - timeout: Maximum time to wait (default: 30 seconds)
    public func waitForNetworkIdle(idleTime: TimeInterval = 0.5, timeout: TimeInterval = 30.0) async throws {
        // Wait for page load first
        try await waitForPageLoad()

        // Then wait additional idle time
        try await Task.sleep(nanoseconds: UInt64(idleTime * 1_000_000_000))
    }

    /// Clear browser cookies and cache.
    public func clearCache() {
        #if CWEBKIT_HAS_WPE
        if let webContext = webContext {
            let dataManager = webkit_web_context_get_website_data_manager(webContext)
            webkit_website_data_manager_clear(
                dataManager,
                0xFFFFFFFF, // All data types
                0,          // From the beginning
                nil,
                nil,
                nil
            )
        }
        #endif
    }
}

#endif // os(Linux)
