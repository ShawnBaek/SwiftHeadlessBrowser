import Foundation

// MARK: - SearchType

public enum SearchType<T: HTMLElement>: Sendable {
    case id(String)
    case name(String)
    case text(String)
    case `class`(String)
    case attribute(String, String)
    case contains(String, String)
    case cssSelector(String)

    public func cssQuery() -> String {
        let tagName = T.cssTagName
        switch self {
        case .id(let value):        return "\(tagName)#\(value)"
        case .name(let value):      return "\(tagName)[name='\(value)']"
        case .text(let value):      return "\(tagName):containsOwn(\(value))"
        case .class(let className): return "\(tagName).\(className)"
        case .attribute(let k, let v): return "\(tagName)[\(k)='\(v)']"
        case .contains(let k, let v):  return "\(tagName)[\(k)*='\(v)']"
        case .cssSelector(let query):  return query
        }
    }
}

// MARK: - Action

/// Async operation that may succeed or fail.
public struct Action<T: Sendable>: Sendable {
    public typealias ResultType = Result<T, ActionError>
    public typealias Completion = @Sendable (ResultType) -> Void

    private let operation: @Sendable (@escaping Completion) -> Void

    public init(result: ResultType) {
        self.init(operation: { $0(result) })
    }

    public init(value: T) {
        self.init(result: .success(value))
    }

    public init(error: ActionError) {
        self.init(result: .failure(error))
    }

    public init(operation: @escaping @Sendable (@escaping Completion) -> Void) {
        self.operation = operation
    }

    public func start(_ completion: @escaping Completion) {
        operation(completion)
    }

    public func execute() async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            start { result in
                switch result {
                case .success(let value): continuation.resume(returning: value)
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
        }
    }

    public func map<U: Sendable>(_ f: @escaping @Sendable (T) -> U) -> Action<U> {
        Action<U>(operation: { completion in
            self.start { result in
                switch result {
                case .success(let value): completion(.success(f(value)))
                case .failure(let error): completion(.failure(error))
                }
            }
        })
    }

    public func andThen<U: Sendable>(_ f: @escaping @Sendable (T) -> Action<U>) -> Action<U> {
        Action<U>(operation: { completion in
            self.start { result in
                switch result {
                case .success(let value): f(value).start(completion)
                case .failure(let error): completion(.failure(error))
                }
            }
        })
    }
}

// MARK: - Operators

infix operator >>>: AdditionPrecedence

public func >>> <T: Sendable, U: Sendable>(a: Action<T>, f: @escaping @Sendable (T) -> Action<U>) -> Action<U> {
    a.andThen(f)
}

// MARK: - PostAction

public enum PostAction: Sendable {
    case wait(TimeInterval)
    case validate(String)
    case none
}

// MARK: - Helpers

extension Data {
    internal func toString() -> String? {
        String(data: self, encoding: .utf8)
    }
}

extension Result where Success: Collection, Failure == ActionError {
    public func first<A>() -> Result<A, ActionError> {
        switch self {
        case .success(let result):
            if let first = result.first as? A { return .success(first) }
            return .failure(.notFound)
        case .failure(let error):
            return .failure(error)
        }
    }
}
