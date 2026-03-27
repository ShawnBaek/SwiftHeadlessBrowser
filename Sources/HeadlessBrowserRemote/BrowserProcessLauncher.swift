//
// BrowserProcessLauncher.swift
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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Manages launching and discovering remote browser processes that support the Chrome DevTools Protocol.
public struct BrowserProcessLauncher: Sendable {

    // MARK: - Browser Launch

    /// Launch Chrome/Chromium in headless mode with remote debugging enabled.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the Chrome binary. If nil, auto-detects.
    ///   - port: Remote debugging port. Use 0 for auto-assignment.
    ///   - additionalArgs: Extra command-line arguments for Chrome.
    /// - Returns: The launched process and the WebSocket debug URL.
    public static func launchChrome(
        binaryPath: String? = nil,
        port: Int = 0,
        additionalArgs: [String] = []
    ) async throws -> (process: Process, webSocketURL: URL) {
        let chromePath = try binaryPath ?? findChromeBinary()
        let actualPort = port == 0 ? findAvailablePort() : port

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("chrome-remote-\(ProcessInfo.processInfo.processIdentifier)")
            .path

        var args = [
            "--headless=new",
            "--disable-gpu",
            "--no-sandbox",
            "--disable-extensions",
            "--disable-background-networking",
            "--disable-default-apps",
            "--disable-sync",
            "--disable-translate",
            "--metrics-recording-only",
            "--no-first-run",
            "--remote-debugging-port=\(actualPort)",
            "--user-data-dir=\(tempDir)",
            "about:blank"
        ]
        args.append(contentsOf: additionalArgs)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: chromePath)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw RemoteBrowserError.browserLaunchFailed("Failed to launch Chrome at \(chromePath): \(error)")
        }

        // Wait for remote browser endpoint to become available
        let wsURL = try await discoverWebSocketURL(host: "127.0.0.1", port: actualPort, timeout: 15.0)

        return (process, wsURL)
    }

    /// Launch Lightpanda in headless mode with remote debugging enabled.
    ///
    /// - Parameters:
    ///   - binaryPath: Path to the Lightpanda binary. If nil, searches PATH.
    ///   - port: Remote debugging port.
    /// - Returns: The launched process and the WebSocket debug URL.
    public static func launchLightpanda(
        binaryPath: String? = nil,
        port: Int = 0
    ) async throws -> (process: Process, webSocketURL: URL) {
        let lpPath = binaryPath ?? "/usr/local/bin/lightpanda"
        let actualPort = port == 0 ? findAvailablePort() : port

        let process = Process()
        process.executableURL = URL(fileURLWithPath: lpPath)
        process.arguments = [
            "--port", "\(actualPort)"
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw RemoteBrowserError.browserLaunchFailed("Failed to launch Lightpanda at \(lpPath): \(error)")
        }

        let wsURL = try await discoverWebSocketURL(host: "127.0.0.1", port: actualPort, timeout: 10.0)

        return (process, wsURL)
    }

    // MARK: - Discovery

    /// Discover the WebSocket debug URL from a running remote browser.
    ///
    /// Polls `http://host:port/json/list` until a page target is found.
    ///
    /// - Parameters:
    ///   - host: The hostname (typically "127.0.0.1").
    ///   - port: The remote debugging port.
    ///   - timeout: Maximum time to wait for the browser to become ready.
    /// - Returns: The WebSocket debug URL for the first page target.
    public static func discoverWebSocketURL(
        host: String,
        port: Int,
        timeout: TimeInterval = 15.0
    ) async throws -> URL {
        let endpointURL = URL(string: "http://\(host):\(port)/json/list")!
        let deadline = Date().addingTimeInterval(timeout)

        while Date() < deadline {
            do {
                let (data, _) = try await fetchData(from: endpointURL)

                guard let targets = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }

                // Find the first "page" target
                for target in targets {
                    if let type = target["type"] as? String, type == "page",
                       let wsURL = target["webSocketDebuggerUrl"] as? String,
                       let url = URL(string: wsURL) {
                        return url
                    }
                }

                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                try await Task.sleep(nanoseconds: 500_000_000)
            }
        }

        throw RemoteBrowserError.browserLaunchFailed(
            "Timed out waiting for remote browser endpoint at \(host):\(port)"
        )
    }

    // MARK: - Chrome Binary Detection

    /// Find the Chrome/Chromium binary on the current system.
    public static func findChromeBinary() throws -> String {
        // Check environment variable first
        if let envPath = ProcessInfo.processInfo.environment["CHROME_BIN"] {
            if FileManager.default.isExecutableFile(atPath: envPath) {
                return envPath
            }
        }

        #if os(macOS)
        let candidates = [
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
            "/Applications/Google Chrome Canary.app/Contents/MacOS/Google Chrome Canary",
            "/opt/homebrew/bin/chromium",
            "/usr/local/bin/chromium"
        ]
        #else
        let candidates = [
            "/usr/bin/google-chrome",
            "/usr/bin/google-chrome-stable",
            "/usr/bin/chromium",
            "/usr/bin/chromium-browser",
            "/snap/bin/chromium",
            "/usr/local/bin/chrome",
            "/usr/local/bin/chromium"
        ]
        #endif

        for candidate in candidates {
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }

        throw RemoteBrowserError.browserLaunchFailed(
            "Chrome/Chromium not found. Set CHROME_BIN environment variable or install Chrome."
        )
    }

    // MARK: - Helpers

    private static func findAvailablePort() -> Int {
        // Bind to port 0 to let the OS assign an available port
        #if os(Linux)
        let socketFD = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        let socketFD = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard socketFD >= 0 else {
            return Int.random(in: 10000...60000)
        }
        defer { close(socketFD) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0 // Let OS pick
        addr.sin_addr.s_addr = INADDR_LOOPBACK.bigEndian

        let bindResult = withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                bind(socketFD, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            return Int.random(in: 10000...60000)
        }

        var boundAddr = sockaddr_in()
        var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                getsockname(socketFD, sockPtr, &addrLen)
            }
        }

        guard nameResult == 0 else {
            return Int.random(in: 10000...60000)
        }

        return Int(UInt16(bigEndian: boundAddr.sin_port))
    }

    private static func fetchData(from url: URL) async throws -> (Data, URLResponse) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        let session = URLSession(configuration: config)
        #if canImport(FoundationNetworking)
        return try await withCheckedThrowingContinuation { continuation in
            session.dataTask(with: url) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data, let response = response {
                    continuation.resume(returning: (data, response))
                } else {
                    continuation.resume(throwing: RemoteBrowserError.connectionFailed("No data"))
                }
            }.resume()
        }
        #else
        return try await session.data(from: url)
        #endif
    }

    /// Terminate a browser process and clean up.
    public static func terminate(_ process: Process) {
        if process.isRunning {
            process.terminate()
        }
    }
}
