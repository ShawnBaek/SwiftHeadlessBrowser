//
// WebKitGTKEngine.swift
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

// MARK: - WebKitGTK Engine

/// A browser engine using WebKitGTK for JavaScript rendering on Linux.
///
/// WebKitGTK is the GTK port of WebKit, providing the same rendering engine
/// as Safari and WKWebView on Apple platforms. This ensures consistent
/// JavaScript execution and DOM rendering across all platforms.
///
/// **Note:** WebKitGTK requires a display server (X11, Wayland, or virtual framebuffer).
/// For truly headless operation, consider using `WPEWebKitEngine` instead.
///
/// ## Installation
///
/// Ubuntu/Debian:
/// ```bash
/// sudo apt-get install libwebkit2gtk-4.1-dev libgtk-4-dev
/// ```
///
/// Fedora:
/// ```bash
/// sudo dnf install webkit2gtk4.1-devel gtk4-devel
/// ```
///
/// ## Running Headless
///
/// Use a virtual framebuffer:
/// ```bash
/// xvfb-run swift test
/// ```
///
/// ## Usage
///
/// ```swift
/// let engine = WebKitGTKEngine(timeoutInSeconds: 60.0)
/// let browser = HeadlessBrowser(name: "MyBrowser", engine: engine)
///
/// let page: HTMLPage = try await browser.open(url: myURL).execute()
/// ```
///
/// ## Reference
/// - https://webkitgtk.org/
/// - https://github.com/WebKit/WebKit (Source/WebKit/gtk)
///
public final class WebKitGTKEngine: BrowserEngine, @unchecked Sendable {

    // MARK: - Properties

    private let _timeoutInSeconds: TimeInterval
    private var _userAgent: UserAgent
    private var currentData: Data?
    private var currentURL: URL?

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    // MARK: - Initialization

    /// Creates a new WebKitGTKEngine instance.
    ///
    /// - Parameters:
    ///   - userAgent: User agent to use for requests
    ///   - timeoutInSeconds: Maximum time to wait for page load (default: 30 seconds)
    public init(userAgent: UserAgent = .safariMac, timeoutInSeconds: TimeInterval = 30.0) {
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds

        // Note: Actual GTK/WebKitGTK initialization happens when CWebKitGTK is available
        #if CWEBKIT_HAS_GTK
        initializeWebKitGTK()
        #endif
    }

    #if CWEBKIT_HAS_GTK
    private func initializeWebKitGTK() {
        // Initialize GTK
        var argc: Int32 = 0
        gtk_init(&argc, nil)

        // Create WebView and configure settings
        // Implementation details depend on actual WebKitGTK bindings
    }
    #endif

    // MARK: - BrowserEngine Protocol

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_GTK
        // Load URL in WebKitGTK WebView
        // Wait for page load
        // Handle post action
        // Return rendered HTML
        throw ActionError.notSupported // Placeholder
        #else
        throw ActionError.notSupported
        #endif
    }

    public func execute(_ script: String) async throws -> String {
        #if CWEBKIT_HAS_GTK
        // Execute JavaScript using webkit_web_view_run_javascript
        throw ActionError.notSupported // Placeholder
        #else
        throw ActionError.notSupported
        #endif
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        #if CWEBKIT_HAS_GTK
        // Execute script and wait for navigation
        throw ActionError.notSupported // Placeholder
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

    // MARK: - Additional Methods

    /// Wait for a CSS selector to appear in the DOM.
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

    /// Wait for network to become idle.
    public func waitForNetworkIdle(idleTime: TimeInterval = 0.5, timeout: TimeInterval = 30.0) async throws {
        try await Task.sleep(nanoseconds: UInt64(idleTime * 1_000_000_000))
    }
}

#endif // os(Linux)
