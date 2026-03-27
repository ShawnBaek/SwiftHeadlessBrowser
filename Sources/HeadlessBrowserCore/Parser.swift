//
// Parser.swift
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
import SwiftSoup

/// Base class for the HTMLParser and JSONParser.
public class Parser: CustomStringConvertible, @unchecked Sendable {

    /// The URL of the page.
    public private(set) var url: URL?

    public init(url: URL? = nil) {
        self.url = url
    }

    public var description: String {
        return "\(type(of: self))"
    }
}

// MARK: - HTML Parser

/// A HTML Parser class using SwiftSoup for parsing.
public class HTMLParser: Parser, @unchecked Sendable {

    private let document: Document
    private let rawData: Data

    public required init(data: Data, url: URL? = nil) throws {
        self.rawData = data
        guard let html = String(data: data, encoding: .utf8) else {
            throw ActionError.parsingFailure
        }
        self.document = try SwiftSoup.parse(html, url?.absoluteString ?? "")
        super.init(url: url)
    }

    /// Search for elements using a CSS selector query.
    public func select(_ cssQuery: String) throws -> Elements {
        return try document.select(cssQuery)
    }

    /// Search for elements using a CSS selector query, returns array of SwiftSoup Elements.
    public func searchWithCSSQuery(_ cssQuery: String) -> [Element]? {
        do {
            let elements = try document.select(cssQuery)
            return elements.array()
        } catch {
            return nil
        }
    }

    /// The raw HTML data.
    public var data: Data? {
        return rawData
    }

    /// The HTML string representation.
    public var html: String {
        return (try? document.outerHtml()) ?? ""
    }

    public override var description: String {
        return html
    }
}

// MARK: - HTML Parser Element

/// A HTML Parser Element class wrapping SwiftSoup Element.
public class HTMLParserElement: CustomStringConvertible, @unchecked Sendable {
    internal let element: Element
    public internal(set) var cssQuery: String?

    public required init?(element: Any, cssQuery: String? = nil) {
        guard let swiftSoupElement = element as? Element else {
            return nil
        }
        self.element = swiftSoupElement
        self.cssQuery = cssQuery
    }

    /// The outer HTML of the element.
    public var innerContent: String? {
        return try? element.outerHtml()
    }

    /// The text content of the element.
    public var text: String? {
        return try? element.text()
    }

    /// The inner HTML content of the element.
    public var content: String? {
        return try? element.html()
    }

    /// The tag name of the element.
    public var tagName: String? {
        return element.tagName()
    }

    /// Get an attribute value by key.
    public func objectForKey(_ key: String) -> String? {
        do {
            let value = try element.attr(key.lowercased())
            return value.isEmpty ? nil : value
        } catch {
            return nil
        }
    }

    /// Get child elements with a specific tag name.
    public func childrenWithTagName<T: HTMLElement>(_ tagName: String) -> [T]? {
        do {
            let children = try element.select(tagName)
            return children.array().compactMap { T(element: $0) }
        } catch {
            return nil
        }
    }

    /// Get all child elements.
    public func children<T: HTMLElement>() -> [T]? {
        return element.children().array().compactMap { T(element: $0) }
    }

    /// Check if the element has children.
    public func hasChildren() -> Bool {
        return !element.children().isEmpty()
    }

    public var description: String {
        return (try? element.outerHtml()) ?? ""
    }

    // Legacy XPathQuery property for backward compatibility
    public var XPathQuery: String? {
        get { return cssQuery }
        set { cssQuery = newValue }
    }
}

// MARK: - JSON Parser

/// A JSON Parser class representing a JSON document.
public class JSONParser: Parser, @unchecked Sendable {

    private var json: JSON?

    public required init(data: Data, url: URL? = nil) {
        super.init(url: url)
        let result: Result<JSON, ActionError> = parseJSON(data)
        switch result {
        case .success(let json): self.json = json
        case .failure: Logger.log("Error parsing JSON!")
        }
    }

    public func content() -> JSON? {
        return json
    }

    public override var description: String {
        return "\(String(describing: json))"
    }
}
