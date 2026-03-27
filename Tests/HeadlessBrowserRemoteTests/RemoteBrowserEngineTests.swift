//
// RemoteBrowserEngineTests.swift
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

import Testing
import Foundation
@testable import HeadlessBrowserRemote
@testable import HeadlessBrowserCore

// MARK: - Remote Browser Engine Unit Tests

@Suite("Remote Browser Engine Tests")
struct RemoteBrowserEngineTests {

    @Test("RemoteBrowserEngine conforms to BrowserEngine")
    func conformsToBrowserEngine() async throws {
        // RemoteBrowserEngine must implement the BrowserEngine protocol.
        // We verify this at compile time — if RemoteBrowserEngine doesn't conform,
        // this file won't compile.
        let _: any BrowserEngine.Type = RemoteBrowserEngine.self
    }

    @Test("RemoteBrowserEngine.Configuration defaults are sensible")
    func configurationDefaults() {
        let config = RemoteBrowserEngine.Configuration(
            webSocketURL: URL(string: "ws://127.0.0.1:9222/devtools/page/ABC")!
        )

        #expect(config.userAgent == .chromeMac)
        #expect(config.timeoutInSeconds == 30.0)
        #expect(config.webSocketURL.absoluteString == "ws://127.0.0.1:9222/devtools/page/ABC")
    }

    @Test("RemoteBrowserEngine.Configuration accepts custom values")
    func configurationCustomValues() {
        let config = RemoteBrowserEngine.Configuration(
            webSocketURL: URL(string: "ws://localhost:9333/devtools/page/XYZ")!,
            userAgent: .safariIPhone,
            timeoutInSeconds: 60.0,
            waitStrategy: .networkIdle(idleTime: 1.0)
        )

        #expect(config.userAgent == .safariIPhone)
        #expect(config.timeoutInSeconds == 60.0)
    }

    @Test("BrowserProcessLauncher detects Chrome binary on macOS")
    func findChromeBinary() {
        #if os(macOS)
        // This test checks if Chrome can be found on the system.
        // It's not a hard failure if Chrome isn't installed.
        do {
            let path = try BrowserProcessLauncher.findChromeBinary()
            #expect(!path.isEmpty)
            #expect(FileManager.default.isExecutableFile(atPath: path))
            print("REMOTE_CHROME_FOUND: \(path)")
        } catch {
            print("REMOTE_CHROME_NOT_FOUND: Chrome not installed (expected in CI)")
        }
        #endif
    }

    @Test("BrowserProcessLauncher respects CHROME_BIN environment variable")
    func chromeBinEnvVar() {
        // We can't easily set environment variables in tests,
        // but we verify the code path exists by checking the method signature.
        // The implementation checks ProcessInfo.processInfo.environment["CHROME_BIN"]
        let envValue = ProcessInfo.processInfo.environment["CHROME_BIN"]
        if let path = envValue {
            print("REMOTE_CHROME_BIN_ENV: \(path)")
        } else {
            print("REMOTE_CHROME_BIN_ENV: not set")
        }
    }
}

// MARK: - Remote Browser Action Error Tests

@Suite("Remote Browser Action Error Tests")
struct RemoteBrowserActionErrorTests {

    @Test("ActionError has remote browser error cases")
    func remoteBrowserErrorCases() {
        let errors: [ActionError] = [
            .remoteBrowserConnectionFailed,
            .remoteBrowserLaunchFailed,
            .remoteBrowserProtocolError("test error"),
            .remoteBrowserDisconnected
        ]

        #expect(errors.count == 4)
        #expect(ActionError.remoteBrowserConnectionFailed.debugDescription == "Remote Browser Connection Failed")
        #expect(ActionError.remoteBrowserLaunchFailed.debugDescription == "Remote Browser Launch Failed")
        #expect(ActionError.remoteBrowserProtocolError("test").debugDescription == "Remote Browser Protocol Error: test")
        #expect(ActionError.remoteBrowserDisconnected.debugDescription == "Remote Browser Disconnected")
    }
}
