import Foundation
import HeadlessBrowserCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// BrowserEngine that uses Lightpanda for headless browsing with full JavaScript support.
/// Runs `lightpanda fetch --dump html` as a subprocess — no WebSocket needed.
/// Auto-downloads to `~/.cache/swift-headless-browser/` on first use.
public final class LightpandaEngine: BrowserEngine, @unchecked Sendable {

    private let binaryPath: String
    private let _userAgent: UserAgent
    private let _timeoutInSeconds: TimeInterval

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    public init(
        binaryPath: String,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0
    ) {
        self.binaryPath = binaryPath
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds
    }

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "fetch",
            "--dump", "html",
            "--wait-until", "load",
            "--log-level", "error",
            url.absoluteString
        ]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ActionError.networkRequestFailure
        }

        let htmlData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if htmlData.isEmpty {
            throw ActionError.networkRequestFailure
        }

        return (htmlData, url)
    }

    // MARK: - Auto-download

    static var cacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache")
            .appendingPathComponent("swift-headless-browser")
    }

    public static var cachedBinaryPath: String {
        cacheDirectory.appendingPathComponent("lightpanda").path
    }

    static var downloadURL: URL {
        let base = "https://github.com/lightpanda-io/browser/releases/download/nightly"
        #if arch(arm64)
        let arch = "aarch64"
        #else
        let arch = "x86_64"
        #endif
        #if os(macOS)
        let platform = "macos"
        #else
        let platform = "linux"
        #endif
        return URL(string: "\(base)/lightpanda-\(arch)-\(platform)")!
    }

    /// Ensure Lightpanda is available, downloading if needed.
    public static func ensureInstalled() async throws -> String {
        let path = cachedBinaryPath
        if FileManager.default.isExecutableFile(atPath: path) { return path }

        print("[SwiftHeadlessBrowser] Downloading Lightpanda...")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let (data, response) = try await URLSession.shared.data(from: downloadURL)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw ActionError.networkRequestFailure
        }

        try data.write(to: URL(fileURLWithPath: path))
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)

        print("[SwiftHeadlessBrowser] Lightpanda installed at \(path)")
        return path
    }
}
