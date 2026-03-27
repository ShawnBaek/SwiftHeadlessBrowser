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
/// Two modules:
/// - **HeadlessBrowserCore**: `HeadlessBrowser` class, HTML parsing, `HeadlessEngine` (HTTP-only)
/// - **HeadlessBrowserRemote**: `RemoteBrowserEngine` — full JavaScript via Chrome/Chromium headless
///
/// ## Quick Start (with JavaScript)
///
/// ```swift
/// import SwiftHeadlessWebKit
///
/// let (browser, process) = try await HeadlessBrowser.withChrome()
/// defer { BrowserProcessLauncher.terminate(process) }
///
/// let page: HTMLPage = try await browser.open(myURL).execute()
/// ```
///
/// ## HTTP-only (no JavaScript, no Chrome needed)
///
/// ```swift
/// let browser = HeadlessBrowser()
/// let page: HTMLPage = try await browser.open(myURL).execute()
/// ```

@_exported import HeadlessBrowserCore
@_exported import HeadlessBrowserRemote
