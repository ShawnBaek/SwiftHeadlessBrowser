import Foundation

/// Protocol for parsed page types.
public protocol Page: Sendable {
    static func pageWithData(_ data: Data?, url: URL?) -> Page?
}
