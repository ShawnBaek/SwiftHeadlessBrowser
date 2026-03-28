import Foundation
import HeadlessBrowserCore

public extension HeadlessBrowser {

    /// Creates a HeadlessBrowser using Lightpanda (auto-downloaded on first use).
    ///
    /// No Chrome installation needed. Lightpanda is automatically downloaded
    /// to `~/.cache/swift-headless-browser/` on first use (~18MB).
    ///
    /// ```swift
    /// let browser = try await HeadlessBrowser.create()
    /// let page: HTMLPage = try await browser.open(myURL).execute()
    /// ```
    static func create(
        name: String? = nil,
        userAgent: UserAgent = .chromeMac,
        timeoutInSeconds: TimeInterval = 30.0
    ) async throws -> HeadlessBrowser {
        let binaryPath = try await LightpandaEngine.ensureInstalled()
        let engine = LightpandaEngine(
            binaryPath: binaryPath,
            userAgent: userAgent,
            timeoutInSeconds: timeoutInSeconds
        )
        return HeadlessBrowser(name: name, engine: engine)
    }
}
