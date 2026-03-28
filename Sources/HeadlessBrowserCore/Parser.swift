import Foundation
import SwiftSoup

// MARK: - HTML Parser

/// Parses HTML using SwiftSoup.
public class HTMLParser: @unchecked Sendable {
    private let document: Document
    private let rawData: Data

    public private(set) var url: URL?

    public required init(data: Data, url: URL? = nil) throws {
        self.rawData = data
        guard let html = String(data: data, encoding: .utf8) else {
            throw ActionError.parsingFailure
        }
        self.document = try SwiftSoup.parse(html, url?.absoluteString ?? "")
        self.url = url
    }

    public func searchWithCSSQuery(_ cssQuery: String) -> [Element]? {
        try? document.select(cssQuery).array()
    }

    public var data: Data? { rawData }
}

// MARK: - HTML Parser Element

/// Wraps a SwiftSoup Element for attribute/text extraction.
public class HTMLParserElement: @unchecked Sendable {
    internal let element: Element

    public required init?(element: Any, cssQuery: String? = nil) {
        guard let el = element as? Element else { return nil }
        self.element = el
    }

    public var text: String? { try? element.text() }

    public func objectForKey(_ key: String) -> String? {
        let value = try? element.attr(key.lowercased())
        return (value?.isEmpty ?? true) ? nil : value
    }

    public func children<T: HTMLElement>() -> [T]? {
        element.children().array().compactMap { T(element: $0) }
    }

    public func hasChildren() -> Bool {
        !element.children().isEmpty()
    }
}
