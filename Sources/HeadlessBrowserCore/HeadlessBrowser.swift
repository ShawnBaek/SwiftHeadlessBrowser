//
// HeadlessBrowser.swift
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

import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Type Aliases

public typealias JavaScript = String
public typealias JavaScriptResult = String
public typealias AuthenticationHandler = @Sendable (URLAuthenticationChallenge) -> (URLSession.AuthChallengeDisposition, URLCredential?)

// MARK: - Browser Engine Protocol

/// Protocol defining the browser engine capabilities.
public protocol BrowserEngine: Sendable {
    /// Open a URL and return the page data.
    func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?)

    /// Execute JavaScript and return the result.
    func execute(_ script: String) async throws -> String

    /// Execute JavaScript that will load a page.
    func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?)

    /// Get the current page content.
    func currentContent() async throws -> (Data, URL?)

    /// User agent string.
    var userAgent: UserAgent { get }

    /// Timeout in seconds.
    var timeoutInSeconds: TimeInterval { get }
}

// MARK: - Headless Engine (Cross-Platform)

/// A headless browser engine that works on all platforms including Linux.
/// This engine fetches HTML via HTTP but cannot execute JavaScript.
public final class HeadlessEngine: BrowserEngine, @unchecked Sendable {

    private let fetcher: ContentFetcher
    private let _userAgent: UserAgent
    private let _timeoutInSeconds: TimeInterval
    private var currentData: Data?
    private var currentURL: URL?

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    public init(userAgent: UserAgent, timeoutInSeconds: TimeInterval = 30.0) {
        self._userAgent = userAgent
        self._timeoutInSeconds = timeoutInSeconds

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeoutInSeconds
        config.httpAdditionalHeaders = ["User-Agent": userAgent.rawValue]
        let session = URLSession(configuration: config)
        self.fetcher = ContentFetcher(session: session)
    }

    public func openURL(_ url: URL, postAction: PostAction = .none) async throws -> (Data, URL?) {
        let (data, response) = try await fetcher.fetch(url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ActionError.networkRequestFailure
        }

        let successRange = 200..<300
        guard successRange.contains(httpResponse.statusCode) else {
            throw ActionError.networkRequestFailure
        }

        self.currentData = data
        self.currentURL = url

        // Handle post action (wait)
        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        return (data, url)
    }

    public func execute(_ script: String) async throws -> String {
        // JavaScript execution is not supported in headless mode on non-Apple platforms
        throw ActionError.notSupported
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        // JavaScript execution is not supported in headless mode
        throw ActionError.notSupported
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let data = currentData else {
            throw ActionError.notFound
        }
        return (data, currentURL)
    }
}

// MARK: - HeadlessBrowser Main Class

/// HeadlessBrowser is a Swift framework for iOS/OSX/Linux to navigate within websites
/// and collect data without the need of User Interface or API.
open class HeadlessBrowser: @unchecked Sendable {

    // MARK: - Properties

    /// The name/identifier of this instance.
    public let name: String

    /// The underlying browser engine.
    public let engine: BrowserEngine

    /// Content fetcher for downloading resources.
    internal let _fetcher: ContentFetcher

    /// Timeout in seconds for operations.
    public var timeoutInSeconds: TimeInterval {
        return engine.timeoutInSeconds
    }

    /// User agent string.
    public var userAgent: String? {
        return engine.userAgent.rawValue
    }

    // MARK: - Shared Instance

    /// Returns the shared HeadlessBrowser instance.
    public static let sharedInstance = HeadlessBrowser()

    // MARK: - Initialization

    /// Creates a new HeadlessBrowser instance.
    ///
    /// - Parameters:
    ///   - name: An optional name/identifier for this instance.
    ///   - engine: The browser engine to use. Defaults to HeadlessEngine.
    public init(name: String? = nil, engine: BrowserEngine? = nil) {
        self.name = name ?? "HeadlessBrowser"
        self.engine = engine ?? HeadlessEngine(userAgent: engine?.userAgent ?? .safariMac)
        self._fetcher = ContentFetcher()
    }

    // MARK: - Response Handling

    internal func _handleResponse(_ data: Data?, response: URLResponse?, error: Error?) -> Result<Data, ActionError> {
        var statusCode: Int = (error == nil) ? ActionError.StatusCodes.success : ActionError.StatusCodes.error
        if let response = response as? HTTPURLResponse {
            statusCode = response.statusCode
        }
        let successRange = 200..<300
        if !successRange.contains(statusCode) || error != nil {
            return .failure(.networkRequestFailure)
        }
        return .success(data ?? Data())
    }
}

// MARK: - Get Page

public extension HeadlessBrowser {
    /// Opens a URL and returns the page.
    ///
    /// - Parameter url: An URL referencing a HTML or JSON page.
    /// - Returns: The HeadlessBrowser Action.
    func open<T: Page>(_ url: URL) -> Action<T> {
        return open(then: .none)(url)
    }

    /// Opens a URL and returns the page with a post action.
    ///
    /// - Parameter postAction: A wait/validation action that will be performed after the page has finished loading.
    /// - Returns: A function that takes a URL and returns the HeadlessBrowser Action.
    func open<T: Page>(then postAction: PostAction) -> @Sendable (_ url: URL) -> Action<T> {
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

    /// Returns the current page.
    ///
    /// - Returns: The HeadlessBrowser Action.
    func inspect<T: Page>() -> Action<T> {
        return Action(operation: { [self] completion in
            Task {
                do {
                    let (data, url) = try await self.engine.currentContent()
                    if let page = T.pageWithData(data, url: url) as? T {
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

// MARK: - Find Methods

public extension HeadlessBrowser {
    /// Searches a page and returns all elements matching the generic HTML element type.
    ///
    /// - Parameter searchType: Key/Value Pairs.
    /// - Returns: A function that takes a page and returns the HeadlessBrowser Action.
    func getAll<T: HTMLElement>(by searchType: SearchType<T>) -> @Sendable (_ page: HTMLPage) -> Action<[T]> {
        return { (page: HTMLPage) -> Action<[T]> in
            let elements: Result<[T], ActionError> = page.findElements(searchType)
            return Action(result: elements)
        }
    }

    /// Searches a page and returns the first element matching the generic HTML element type.
    ///
    /// - Parameter searchType: Key/Value Pairs.
    /// - Returns: A function that takes a page and returns the HeadlessBrowser Action.
    func get<T: HTMLElement>(by searchType: SearchType<T>) -> @Sendable (_ page: HTMLPage) -> Action<T> {
        return { (page: HTMLPage) -> Action<T> in
            let elements: Result<[T], ActionError> = page.findElements(searchType)
            return Action(result: elements.first())
        }
    }
}

// MARK: - JavaScript Methods

public extension HeadlessBrowser {
    /// Executes a JavaScript string.
    ///
    /// - Parameter script: A JavaScript string.
    /// - Returns: The HeadlessBrowser Action.
    func execute(_ script: JavaScript) -> Action<JavaScriptResult> {
        return Action(operation: { [self] completion in
            Task {
                do {
                    let result = try await self.engine.execute(script)
                    Logger.log("Script Result".uppercased() + "\n\(result)\n")
                    completion(.success(result))
                } catch let error as ActionError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.networkRequestFailure))
                }
            }
        })
    }

    /// Executes a JavaScript string on the given page.
    ///
    /// - Parameter script: A JavaScript string.
    /// - Returns: A function that takes a page and returns the HeadlessBrowser Action.
    func execute<T: HTMLPage>(_ script: JavaScript) -> @Sendable (_ page: T) -> Action<JavaScriptResult> {
        return { [self] (_: T) -> Action<JavaScriptResult> in
            return self.execute(script)
        }
    }
}

// MARK: - Fetch Actions

public extension HeadlessBrowser {
    /// Downloads the linked data of the passed HTMLFetchable object.
    ///
    /// - Parameter fetchable: A HTMLElement that implements the HTMLFetchable protocol.
    /// - Returns: The HeadlessBrowser Action.
    func fetch<T: HTMLElement & HTMLFetchable>(_ fetchable: T) -> Action<T> {
        return Action(operation: { [self] completion in
            guard let fetchURL = fetchable.fetchURL else {
                completion(.failure(.notFound))
                return
            }
            self._fetcher.fetch(fetchURL) { result, response, error in
                let data = self._handleResponse(result, response: response, error: error)
                switch data {
                case .success(let value):
                    Task {
                        await fetchable.setFetchedDataAsync(value)
                        completion(.success(fetchable))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        })
    }
}

// MARK: - Transform Actions

public extension HeadlessBrowser {
    /// Transforms a HTMLElement into another type using the specified function.
    ///
    /// - Parameter f: The function that takes a certain HTMLElement as parameter and transforms it.
    /// - Returns: A function that takes an object and returns the HeadlessBrowser Action.
    func map<T: Sendable, A: Sendable>(_ f: @escaping @Sendable (T) -> A) -> @Sendable (_ object: T) -> Action<A> {
        return { (object: T) -> Action<A> in
            return Action(result: resultFromOptional(f(object), error: .notFound))
        }
    }

    /// Transforms an object into another object using the specified closure.
    ///
    /// - Parameter f: The closure that takes an object as parameter and transforms it.
    /// - Returns: A function that takes an object and returns the transformed object.
    func map<T, A>(_ f: @escaping (T) -> A) -> (_ object: T) -> A {
        return { (object: T) -> A in
            return f(object)
        }
    }
}

// MARK: - Advanced Actions

public extension HeadlessBrowser {
    /// Executes the specified action until a condition is met.
    ///
    /// - Parameters:
    ///   - f: The Action which will be executed.
    ///   - until: If 'true', the execution of the specified Action will stop.
    /// - Returns: A function that takes an initial value and returns the collected Action results.
    func collect<T: Sendable>(_ f: @escaping @Sendable (T) -> Action<T>, until: @escaping @Sendable (T) -> Bool) -> @Sendable (_ initial: T) -> Action<[T]> {
        return { (initial: T) -> Action<[T]> in
            return Action.collect(initial, f: f, until: until)
        }
    }

    /// Makes a bulk execution of the specified action with the provided input values.
    ///
    /// - Parameter f: The Action.
    /// - Returns: A function that takes an array of elements and returns the collected Action results.
    func batch<T: Sendable, U: Sendable>(_ f: @escaping @Sendable (T) -> Action<U>) -> @Sendable (_ elements: [T]) -> Action<[U]> {
        return { (elements: [T]) -> Action<[U]> in
            return Action.batch(elements, f: f)
        }
    }
}

// MARK: - JSON Actions

public extension HeadlessBrowser {
    /// Parses Data and creates a JSON object.
    ///
    /// - Parameter data: A Data object.
    /// - Returns: A JSON object.
    func parse<T>(_ data: Data) -> Action<T> {
        return Action(result: parseJSON(data))
    }

    /// Takes a JSONParsable and decodes it into a Model object.
    ///
    /// - Parameter element: A JSONParsable instance.
    /// - Returns: A JSONDecodable object.
    func decode<T: JSONDecodable>(_ element: JSONParsable) -> Action<T> {
        return Action(result: decodeJSON(element.content()))
    }

    /// Takes a JSONParsable and decodes it into an array of Model objects.
    ///
    /// - Parameter array: A JSONParsable instance.
    /// - Returns: A JSONDecodable array.
    func decode<T: JSONDecodable>(_ array: JSONParsable) -> Action<[T]> {
        return Action(result: decodeJSON(array.content()))
    }
}

// MARK: - Debug Methods

public extension HeadlessBrowser {
    /// Prints the current state of the HeadlessBrowser to the console.
    func dump() {
        Task {
            do {
                let (data, _) = try await engine.currentContent()
                if let output = data.toString() {
                    Logger.log(output)
                } else {
                    Logger.log("No Output available.")
                }
            } catch {
                Logger.log("Error getting content: \(error)")
            }
        }
    }
}
