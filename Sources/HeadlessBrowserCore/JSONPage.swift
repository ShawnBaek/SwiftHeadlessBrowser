//
// JSONPage.swift
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

/// Protocol which must be implemented by JSON models in order to get decoded.
public protocol JSONDecodable {
    /// Returns the decoded JSON data represented as a model object.
    ///
    /// - Parameter json: The JSON data.
    /// - Returns: The model object.
    static func decode(_ json: JSONElement) -> Self?
}

/// Protocol which must be implemented by objects in order to get parsed as JSON.
public protocol JSONParsable {
    /// Returns the parsable JSON data.
    ///
    /// - Returns: The JSON data.
    func content() -> JSON?
}

/// JSONPage class representing the entire JSON document.
public class JSONPage: JSONParser, Page, JSONParsable, @unchecked Sendable {

    /// Returns a JSON page instance for the specified JSON data.
    ///
    /// - Parameters:
    ///   - data: The JSON data.
    ///   - url: The URL of the page.
    /// - Returns: A JSON page.
    public static func pageWithData(_ data: Data?, url: URL?) -> Page? {
        if let data = data {
            return JSONPage(data: data, url: url)
        }
        return nil
    }
}
