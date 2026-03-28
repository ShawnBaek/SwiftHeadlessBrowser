import Foundation

public enum ActionError: Error, Sendable, Equatable {
    case networkRequestFailure
    case notFound
    case parsingFailure
    case notSupported
}
