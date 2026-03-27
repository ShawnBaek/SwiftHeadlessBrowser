//
//  HTMLPage.swift
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

/// HTMLPage class, which represents the DOM of a HTML page.
public class HTMLPage: HTMLParser, Page, @unchecked Sendable {

    // MARK: - Initializer

    /// Returns a HTML page instance for the specified HTML DOM data.
    ///
    /// - Parameters:
    ///   - data: The HTML DOM data.
    ///   - url: The URL of the page.
    /// - Returns: A HTML page.
    public static func pageWithData(_ data: Data?, url: URL?) -> Page? {
        guard let data = data else { return nil }
        return try? HTMLPage(data: data, url: url)
    }

    // MARK: - Find Elements

    /// Find elements matching the search type.
    ///
    /// - Parameter searchType: The search type to use.
    /// - Returns: A result containing the found elements or an error.
    public func findElements<T: HTMLElement>(_ searchType: SearchType<T>) -> Result<[T], ActionError> {
        let query = searchType.cssQuery()
        if let parsedObjects = searchWithCSSQuery(query), !parsedObjects.isEmpty {
            let elements = parsedObjects.compactMap { T(element: $0, cssQuery: query) }
            if elements.isEmpty {
                return .failure(.notFound)
            }
            return .success(elements)
        }
        return .failure(.notFound)
    }
}
