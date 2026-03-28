import Foundation
import HeadlessBrowserCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A BrowserEngine that uses Lightpanda for headless browsing.
///
/// Lightpanda is a lightweight headless browser with full JavaScript support.
/// This engine runs `lightpanda fetch --dump html` as a subprocess — no WebSocket needed.
///
/// On first use, Lightpanda is automatically downloaded to `~/.cache/swift-headless-browser/`.
public final class LightpandaEngine: BrowserEngine, @unchecked Sendable {

    private let binaryPath: String
    private let _userAgent: UserAgent
    private let _timeoutInSeconds: TimeInterval
    private var currentData: Data?
    private var currentURL: URL?

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
            throw RemoteBrowserError.browserLaunchFailed("Failed to run Lightpanda: \(error)")
        }

        // Read all stdout data first, then wait for process to exit
        let htmlData = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if htmlData.isEmpty {
            let errData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errText = String(data: errData, encoding: .utf8) ?? ""
            throw RemoteBrowserError.navigationFailed(
                errText.isEmpty ? "Lightpanda returned empty output for \(url)" : String(errText.prefix(500))
            )
        }

        self.currentData = htmlData
        self.currentURL = url

        // Handle PostAction
        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        return (htmlData, url)
    }

    public func execute(_ script: String) async throws -> String {
        // Lightpanda fetch mode doesn't support standalone JS execution
        // Use Runtime.evaluate via CDP serve mode for this
        throw ActionError.notSupported
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        throw ActionError.notSupported
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else { throw ActionError.notFound }
        return (data, currentURL)
    }

    // MARK: - Auto-download

    /// Cache directory for Lightpanda binary.
    public static var cacheDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".cache")
            .appendingPathComponent("swift-headless-browser")
    }

    /// Path to the cached Lightpanda binary.
    public static var cachedBinaryPath: String {
        cacheDirectory.appendingPathComponent("lightpanda").path
    }

    /// Download URL for the current platform.
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
    /// Returns the path to the binary.
    public static func ensureInstalled() async throws -> String {
        let path = cachedBinaryPath

        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        print("[SwiftHeadlessBrowser] Downloading Lightpanda...")
        try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        let url = downloadURL
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw RemoteBrowserError.browserLaunchFailed(
                "Failed to download Lightpanda from \(url)"
            )
        }

        let fileURL = URL(fileURLWithPath: path)
        try data.write(to: fileURL)

        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: path
        )

        print("[SwiftHeadlessBrowser] Lightpanda installed at \(path)")
        return path
    }
}
