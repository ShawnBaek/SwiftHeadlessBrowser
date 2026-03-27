//
// SwiftHeadlessWebKit.swift
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

/// SwiftHeadlessWebKit - A cross-platform headless web browser for Swift.
///
/// This unified module automatically provides the correct implementation
/// for each platform:
/// - **macOS/iOS**: Uses WKWebView for full JavaScript support
/// - **Linux**: Uses HeadlessEngine for HTTP-based scraping
///
/// ## Quick Start
///
/// ```swift
/// import SwiftHeadlessWebKit
///
/// let browser = HeadlessBrowser()
/// let page: HTMLPage = try await browser.open(url: myURL).execute()
/// let elements = page.findElements(.cssSelector("a.link"))
/// ```
///
/// ## Custom Configuration
///
/// ```swift
/// let engine = HeadlessEngine(
///     userAgent: "MyBot/1.0",
///     timeoutInSeconds: 30.0
/// )
/// let browser = HeadlessBrowser(name: "MyBot", engine: engine)
/// ```

// Re-export core module (available on all platforms)
@_exported import HeadlessBrowserCore

// Re-export remote browser engine (available on all platforms - full JavaScript support via Chrome DevTools Protocol)
@_exported import HeadlessBrowserRemote

// Re-export platform-specific modules
#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
@_exported import HeadlessBrowserApple
#elseif os(Linux)
@_exported import HeadlessBrowserLinux
#endif
