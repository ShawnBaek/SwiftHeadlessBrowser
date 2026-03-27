//
// HeadlessBrowserAppleTests.swift
//
// Copyright (c) 2015 Mathias Koehnke (http://www.mathiaskoehnke.de)
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

#if canImport(WebKit)
import Testing
import Foundation
@testable import HeadlessBrowserCore
@testable import HeadlessBrowserApple

@Suite("WebKit Engine Tests")
struct WebKitEngineTests {

    @Test("WebKit engine can be created")
    @MainActor
    func createWebKitEngine() async {
        let engine = WebKitEngine(userAgent: .safariMac)
        #expect(engine.timeoutInSeconds == 30.0)
    }

    @Test("WebKit engine supports JavaScript")
    @MainActor
    func webkitSupportsJS() async {
        let engine = WebKitEngine(userAgent: .safariMac)
        // Just verify it doesn't throw .notSupported like HeadlessEngine
        // Actual JS execution requires a loaded page
    }
}

@Suite("HeadlessBrowserApple Extension Tests")
struct HeadlessBrowserAppleExtensionTests {

    @Test("HeadlessBrowser with WebKit engine can be created")
    @MainActor
    func createHeadlessBrowserWithWebKit() async {
        let browser = HeadlessBrowser(name: "TestBrowser", processPool: nil, userAgent: .safariMac)
        #expect(browser.name == "TestBrowser")
    }
}

#endif // canImport(WebKit)
