//
// HeadlessBrowserLinux.swift
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
@_exported import HeadlessBrowserCore

// MARK: - SwiftHeadlessWebKit Linux Module

/// SwiftHeadlessWebKit Linux Extensions
///
/// This module provides WebKit-based JavaScript rendering on Linux using
/// the official WebKit ports from https://github.com/WebKit/WebKit:
///
/// - **WPE WebKit** (`WPEWebKitEngine`): Headless WebKit designed for embedded
///   systems and server-side rendering. Recommended for production use.
///
/// - **WebKitGTK** (`WebKitGTKEngine`): WebKit with GTK integration. Requires
///   a display server (use `xvfb-run` for headless operation).
///
/// Both engines use the same WebKit codebase as Safari and WKWebView on Apple
/// platforms, ensuring consistent rendering and JavaScript execution.
///
/// ## Quick Start
///
/// ```swift
/// import HeadlessBrowserLinux
///
/// // Create browser with WPE WebKit (headless)
/// let browser = HeadlessBrowser.withWebKitSupport(name: "MyBrowser")
///
/// // Open a JavaScript-heavy page
/// let page: HTMLPage = try await browser.open(
///     url: URL(string: "https://example.com")!
/// ).execute()
///
/// // JavaScript has been executed, DOM is fully rendered
/// let elements = page.findElements(.cssSelector(".dynamic-content"))
/// ```
///
/// ## Installation
///
/// ### WPE WebKit (Recommended for Headless)
/// ```bash
/// # Ubuntu/Debian
/// sudo apt-get install libwpewebkit-1.1-dev libwpe-1.0-dev
///
/// # Fedora
/// sudo dnf install wpewebkit-devel wpebackend-fdo-devel
/// ```
///
/// ### WebKitGTK (Requires Display)
/// ```bash
/// # Ubuntu/Debian
/// sudo apt-get install libwebkit2gtk-4.1-dev xvfb
///
/// # Run with virtual framebuffer
/// xvfb-run swift test
/// ```
///
/// ## Reference
/// - https://github.com/WebKit/WebKit
/// - https://wpewebkit.org/
/// - https://webkitgtk.org/

// MARK: - Convenience Factory Methods

public extension HeadlessBrowser {

    /// Creates a HeadlessBrowser instance with WebKit JavaScript rendering support.
    ///
    /// On Linux, this uses WPE WebKit (the headless WebKit port) for full
    /// JavaScript execution and DOM rendering, matching the behavior of
    /// WKWebView on Apple platforms.
    ///
    /// - Parameters:
    ///   - name: Optional name for the browser instance
    ///   - userAgent: User agent to use for requests
    ///   - timeoutInSeconds: Maximum time to wait for page loads (default: 30s)
    /// - Returns: A HeadlessBrowser instance configured for JavaScript rendering
    ///
    /// ## Example
    ///
    /// ```swift
    /// let browser = HeadlessBrowser.withWebKitSupport(name: "Scraper")
    ///
    /// // This will render JavaScript before returning
    /// let page: HTMLPage = try await browser.open(
    ///     url: URL(string: "https://spa-website.com")!
    /// ).execute()
    /// ```
    static func withWebKitSupport(
        name: String? = nil,
        userAgent: UserAgent = .safariMac,
        timeoutInSeconds: TimeInterval = 30.0
    ) -> HeadlessBrowser {
        let engine = WPEWebKitEngine(
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds
        )
        return HeadlessBrowser(name: name, engine: engine)
    }

    /// Creates a HeadlessBrowser instance using WebKitGTK.
    ///
    /// WebKitGTK requires a display server. Use `xvfb-run` for headless operation:
    /// ```bash
    /// xvfb-run swift run myapp
    /// ```
    ///
    /// - Parameters:
    ///   - name: Optional name for the browser instance
    ///   - userAgent: User agent to use for requests
    ///   - timeoutInSeconds: Maximum time to wait for page loads (default: 30s)
    /// - Returns: A HeadlessBrowser instance configured with WebKitGTK
    static func withWebKitGTK(
        name: String? = nil,
        userAgent: UserAgent = .safariMac,
        timeoutInSeconds: TimeInterval = 30.0
    ) -> HeadlessBrowser {
        let engine = WebKitGTKEngine(
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds
        )
        return HeadlessBrowser(name: name, engine: engine)
    }
}

#endif // os(Linux)
