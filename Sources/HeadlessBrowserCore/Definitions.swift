//
// Definitions.swift
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

// MARK: - SearchType

public enum SearchType<T: HTMLElement>: Sendable {
    /// Returns an element that matches the specified id.
    case id(String)
    /// Returns all elements matching the specified value for their name attribute.
    case name(String)
    /// Returns all elements with inner content that contain the specified text.
    case text(String)
    /// Returns all elements that match the specified class name.
    case `class`(String)
    /// Returns all elements that match the specified attribute name/value combination.
    case attribute(String, String)
    /// Returns all elements with an attribute containing the specified value.
    case contains(String, String)
    /// Returns all elements that match the specified CSS selector query.
    case cssSelector(String)

    @available(*, deprecated, renamed: "cssSelector")
    case XPathQuery(String)

    public func cssQuery() -> String {
        let tagName = T.cssTagName
        switch self {
        case .id(let value):
            return "\(tagName)#\(value)"
        case .name(let value):
            return "\(tagName)[name='\(value)']"
        case .text(let value):
            return "\(tagName):containsOwn(\(value))"
        case .class(let className):
            return "\(tagName).\(className)"
        case .attribute(let key, let value):
            return "\(tagName)[\(key)='\(value)']"
        case .contains(let key, let value):
            return "\(tagName)[\(key)*='\(value)']"
        case .cssSelector(let query), .XPathQuery(let query):
            return query
        }
    }
}

// MARK: - Action

/// A monadic type representing asynchronous operations that may succeed or fail.
public struct Action<T: Sendable>: Sendable {
    public typealias ResultType = Result<T, ActionError>
    public typealias Completion = @Sendable (ResultType) -> Void
    public typealias AsyncOperation = @Sendable (@escaping Completion) -> Void

    private let operation: AsyncOperation

    public init(result: ResultType) {
        self.init(operation: { completion in
            completion(result)
        })
    }

    public init(value: T) {
        self.init(result: .success(value))
    }

    public init(error: ActionError) {
        self.init(result: .failure(error))
    }

    public init(operation: @escaping AsyncOperation) {
        self.operation = operation
    }

    public func start(_ completion: @escaping Completion) {
        self.operation { result in
            completion(result)
        }
    }

    // MARK: - Async/Await Support

    public func execute() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            self.start { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

// MARK: - Action Transformations

public extension Action {
    func map<U: Sendable>(_ f: @escaping @Sendable (T) -> U) -> Action<U> {
        return Action<U>(operation: { completion in
            self.start { result in
                switch result {
                case .success(let value):
                    completion(.success(f(value)))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        })
    }

    func flatMap<U: Sendable>(_ f: @escaping @Sendable (T) -> U?) -> Action<U> {
        return Action<U>(operation: { completion in
            self.start { result in
                switch result {
                case .success(let value):
                    if let result = f(value) {
                        completion(.success(result))
                    } else {
                        completion(.failure(.transformFailure))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        })
    }

    func andThen<U: Sendable>(_ f: @escaping @Sendable (T) -> Action<U>) -> Action<U> {
        return Action<U>(operation: { completion in
            self.start { firstResult in
                switch firstResult {
                case .success(let value):
                    f(value).start(completion)
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        })
    }
}

// MARK: - Action Collection Methods

public extension Action {
    /// Executes the specified action until a condition is met.
    static func collect(_ initial: T, f: @escaping @Sendable (T) -> Action<T>, until: @escaping @Sendable (T) -> Bool) -> Action<[T]> {
        return Action<[T]>(operation: { completion in
            Task {
                var values = [T]()
                var current = initial

                do {
                    while true {
                        let result = try await f(current).execute()
                        values.append(result)
                        if !until(result) {
                            completion(.success(values))
                            return
                        }
                        current = result
                    }
                } catch let error as ActionError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.networkRequestFailure))
                }
            }
        })
    }

    /// Makes a bulk execution of the specified action with the provided input values.
    static func batch<U: Sendable>(_ elements: [T], f: @escaping @Sendable (T) -> Action<U>) -> Action<[U]> {
        return Action<[U]>(operation: { completion in
            Task {
                var results = [U]()
                for element in elements {
                    do {
                        let result = try await f(element).execute()
                        results.append(result)
                    } catch let error as ActionError {
                        completion(.failure(error))
                        return
                    } catch {
                        completion(.failure(.networkRequestFailure))
                        return
                    }
                }
                completion(.success(results))
            }
        })
    }
}

// MARK: - Operators

infix operator >>>: AdditionPrecedence

/// Chain operator: passes the result of the left action to the right function.
public func >>> <T: Sendable, U: Sendable>(a: Action<T>, f: @escaping @Sendable (T) -> Action<U>) -> Action<U> {
    return a.andThen(f)
}

/// Chain operator: ignores the result of the left action and executes the right action.
public func >>> <T: Sendable, U: Sendable>(a: Action<T>, b: Action<U>) -> Action<U> {
    let f: @Sendable (T) -> Action<U> = { _ in b }
    return a.andThen(f)
}

/// Chain operator for functions returning actions.
public func >>> <T: Sendable, U: Page>(a: Action<T>, f: @Sendable () -> Action<U>) -> Action<U> {
    return a >>> f()
}

/// Chain operator for functions returning actions.
public func >>> <T: Page, U: Sendable>(a: @Sendable () -> Action<T>, f: @escaping @Sendable (T) -> Action<U>) -> Action<U> {
    return a() >>> f
}

infix operator ===: AssignmentPrecedence

/// Completion operator: starts the action and passes the optional result to the completion handler.
public func === <T: Sendable>(a: Action<T>, completion: @escaping @Sendable (T?) -> Void) {
    a.start { result in
        switch result {
        case .success(let value): completion(value)
        case .failure: completion(nil)
        }
    }
}

/// Completion operator: starts the action and passes the result to the completion handler.
public func === <T: Sendable>(a: Action<T>, completion: @escaping @Sendable (Result<T, ActionError>) -> Void) {
    a.start { result in
        completion(result)
    }
}

// MARK: - Response

internal struct Response: Sendable {
    var data: Data?
    var statusCode: Int = ActionError.StatusCodes.error

    init(data: Data?, urlResponse: URLResponse) {
        self.data = data
        if let httpResponse = urlResponse as? HTTPURLResponse {
            self.statusCode = httpResponse.statusCode
        }
    }

    init(data: Data?, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }
}

// MARK: - Internal Result Operators

internal func parseResponse(_ response: Response) -> Result<Data, ActionError> {
    let successRange = 200..<300
    if !successRange.contains(response.statusCode) {
        return .failure(.networkRequestFailure)
    }
    return .success(response.data ?? Data())
}

internal func resultFromOptional<A>(_ optional: A?, error: ActionError) -> Result<A, ActionError> {
    if let a = optional {
        return .success(a)
    } else {
        return .failure(error)
    }
}

internal func decodeResult<T: Page>(_ url: URL? = nil) -> @Sendable (_ data: Data?) -> Result<T, ActionError> {
    return { (data: Data?) -> Result<T, ActionError> in
        return resultFromOptional(T.pageWithData(data, url: url) as? T, error: .networkRequestFailure)
    }
}

internal func decodeString(_ data: Data?) -> Result<String, ActionError> {
    return resultFromOptional(data?.toString(), error: .transformFailure)
}

// MARK: - PostAction

/// An action that will be performed after the page has finished loading.
public enum PostAction: Sendable {
    /// Wait for a specified time after page load.
    case wait(TimeInterval)
    /// Wait until a JavaScript expression returns true.
    case validate(String)
    /// No post action.
    case none
}

// MARK: - JSON Types

public typealias JSON = Any
public typealias JSONElement = [String: Any]

internal func parseJSON<U>(_ data: Data) -> Result<U, ActionError> {
    var jsonOptional: U?
    var __error = ActionError.parsingFailure

    do {
        if let data = htmlToData(NSString(data: data, encoding: String.Encoding.utf8.rawValue)) {
            jsonOptional = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions(rawValue: 0)) as? U
        }
    } catch {
        __error = .parsingFailure
        jsonOptional = nil
    }

    return resultFromOptional(jsonOptional, error: __error)
}

internal func decodeJSON<U: JSONDecodable>(_ json: JSON?) -> Result<U, ActionError> {
    if let element = json as? JSONElement {
        return resultFromOptional(U.decode(element), error: .parsingFailure)
    }
    return .failure(.parsingFailure)
}

internal func decodeJSON<U: JSONDecodable>(_ json: JSON?) -> Result<[U], ActionError> {
    if let elements = json as? [JSONElement] {
        var result = [U]()
        for element in elements {
            let decodable: Result<U, ActionError> = decodeJSON(element as JSON?)
            switch decodable {
            case .success(let value): result.append(value)
            case .failure(let error): return .failure(error)
            }
        }
        return .success(result)
    }
    return .success([])
}

// MARK: - Helper Methods

private func htmlToData(_ html: NSString?) -> Data? {
    if let html = html {
        let json = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression, range: NSMakeRange(0, html.length))
        return json.data(using: String.Encoding.utf8)
    }
    return nil
}

extension Dictionary: JSONParsable {
    public func content() -> JSON? {
        return self
    }
}

extension Array: JSONParsable {
    public func content() -> JSON? {
        return self
    }
}

extension String {
    internal func terminate() -> String {
        let terminator: Character = ";"
        var trimmed = trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        if trimmed.last != terminator { trimmed += String(terminator) }
        return trimmed
    }
}

extension Data {
    internal func toString() -> String? {
        return String(data: self, encoding: String.Encoding.utf8)
    }
}

internal func delay(_ time: TimeInterval, completion: @escaping @Sendable () -> Void) {
    Task {
        try? await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        completion()
    }
}

// MARK: - Result Extension

extension Result where Success: Collection, Failure == ActionError {
    public func first<A>() -> Result<A, ActionError> {
        switch self {
        case .success(let result):
            return resultFromOptional(result.first as? A, error: .notFound)
        case .failure(let error):
            return .failure(error)
        }
    }
}
