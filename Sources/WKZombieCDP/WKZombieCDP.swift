//
// WKZombieCDP.swift
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
import WKZombie

// MARK: - WKZombie CDP Convenience Factory Methods

public extension WKZombie {

    /// Creates a WKZombie instance backed by a CDP engine, connecting to an existing browser.
    ///
    /// Use this when you have an already-running CDP-compatible browser
    /// (Chrome headless, Chromium, Lightpanda) and know its WebSocket URL.
    ///
    /// ```swift
    /// let browser = try await WKZombie.withCDP(
    ///     webSocketURL: URL(string: "ws://127.0.0.1:9222/devtools/page/ABC")!
    /// )
    /// let page: HTMLPage = try await browser.open(myURL).execute()
    /// ```
    ///
    /// - Parameters:
    ///   - name: An optional name/identifier for this instance.
    ///   - webSocketURL: The WebSocket debug URL of a CDP page target.
    ///   - userAgent: The user agent to use. Defaults to `.chromeMac`.
    ///   - timeoutInSeconds: Timeout for operations. Defaults to 30.
    ///   - waitStrategy: Strategy for determining when pages are loaded. Defaults to `.load`.
    /// - Returns: A configured WKZombie instance with full JavaScript support.
    static func withCDP(
        name: String? = nil,
        webSocketURL: URL,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0,
        waitStrategy: CDPWaitStrategy = .load
    ) async throws -> WKZombie {
        let config = CDPEngine.Configuration(
            webSocketURL: webSocketURL,
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds,
            waitStrategy: waitStrategy
        )
        let engine = try await CDPEngine(configuration: config)
        return WKZombie(name: name, engine: engine)
    }

    /// Creates a WKZombie instance that auto-launches Chrome in headless mode.
    ///
    /// This is the easiest way to get full JavaScript support. Chrome must be
    /// installed on the system (or specify a custom path).
    ///
    /// ```swift
    /// let (browser, process) = try await WKZombie.withChrome()
    /// defer { CDPBrowserLauncher.terminate(process) }
    ///
    /// let page: HTMLPage = try await browser.open(myURL).execute()
    /// ```
    ///
    /// - Parameters:
    ///   - name: An optional name/identifier for this instance.
    ///   - chromePath: Path to Chrome binary. If nil, auto-detects.
    ///   - port: CDP debugging port. Use 0 for auto-assignment.
    ///   - userAgent: The user agent to use. Defaults to `.chromeMac`.
    ///   - timeoutInSeconds: Timeout for operations. Defaults to 30.
    ///   - waitStrategy: Strategy for determining when pages are loaded.
    /// - Returns: A tuple of the configured WKZombie and the Chrome Process (caller should terminate).
    static func withChrome(
        name: String? = nil,
        chromePath: String? = nil,
        port: Int = 0,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0,
        waitStrategy: CDPWaitStrategy = .load
    ) async throws -> (browser: WKZombie, process: Process) {
        let (process, wsURL) = try await CDPBrowserLauncher.launchChrome(
            binaryPath: chromePath,
            port: port
        )

        let browser = try await WKZombie.withCDP(
            name: name,
            webSocketURL: wsURL,
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds,
            waitStrategy: waitStrategy
        )

        return (browser, process)
    }

    /// Creates a WKZombie instance that auto-launches Lightpanda.
    ///
    /// Lightpanda is a fast, lightweight headless browser with full JavaScript support.
    ///
    /// - Parameters:
    ///   - name: An optional name/identifier for this instance.
    ///   - binaryPath: Path to Lightpanda binary. If nil, uses default location.
    ///   - port: CDP debugging port. Use 0 for auto-assignment.
    ///   - userAgent: The user agent to use. Defaults to `.chromeMac`.
    ///   - timeoutInSeconds: Timeout for operations. Defaults to 30.
    ///   - waitStrategy: Strategy for determining when pages are loaded.
    /// - Returns: A tuple of the configured WKZombie and the Lightpanda Process.
    static func withLightpanda(
        name: String? = nil,
        binaryPath: String? = nil,
        port: Int = 0,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0,
        waitStrategy: CDPWaitStrategy = .load
    ) async throws -> (browser: WKZombie, process: Process) {
        let (process, wsURL) = try await CDPBrowserLauncher.launchLightpanda(
            binaryPath: binaryPath,
            port: port
        )

        let browser = try await WKZombie.withCDP(
            name: name,
            webSocketURL: wsURL,
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds,
            waitStrategy: waitStrategy
        )

        return (browser, process)
    }
}
