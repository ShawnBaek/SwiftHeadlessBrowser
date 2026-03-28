import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Browser Engine Protocol

/// Protocol defining the browser engine capabilities.
public protocol BrowserEngine: Sendable {
    /// Open a URL and return the rendered page data.
    func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?)

    /// User agent string.
    var userAgent: UserAgent { get }

    /// Timeout in seconds.
    var timeoutInSeconds: TimeInterval { get }
}

// MARK: - HeadlessBrowser

/// A headless browser for server-side web scraping with full JavaScript support.
///
/// ```swift
/// let browser = try await HeadlessBrowser.create()
/// let page: HTMLPage = try await browser.open(url).execute()
/// let jobs = page.findElements(.cssSelector("a[href*='/jobs/']"))
/// ```
open class HeadlessBrowser: @unchecked Sendable {

    /// The name/identifier of this instance.
    public let name: String

    /// The underlying browser engine.
    public let engine: BrowserEngine

    /// Creates a new HeadlessBrowser instance with a browser engine.
    public init(name: String? = nil, engine: BrowserEngine) {
        self.name = name ?? "HeadlessBrowser"
        self.engine = engine
    }

    /// Opens a URL and returns the parsed page.
    public func open<T: Page>(_ url: URL) -> Action<T> {
        return open(then: .none)(url)
    }

    /// Opens a URL with a post action and returns the parsed page.
    public func open<T: Page>(then postAction: PostAction) -> @Sendable (_ url: URL) -> Action<T> {
        return { [self] (url: URL) -> Action<T> in
            return Action(operation: { completion in
                Task {
                    do {
                        let (data, responseURL) = try await self.engine.openURL(url, postAction: postAction)
                        if let page = T.pageWithData(data, url: responseURL) as? T {
                            completion(.success(page))
                        } else {
                            completion(.failure(.parsingFailure))
                        }
                    } catch let error as ActionError {
                        completion(.failure(error))
                    } catch {
                        completion(.failure(.networkRequestFailure))
                    }
                }
            })
        }
    }
}
