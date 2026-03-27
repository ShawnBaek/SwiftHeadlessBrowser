//
// ContentFetcher.swift
//
// Copyright (c) 2016 Mathias Koehnke (http://www.mathiaskoehnke.de)
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

public typealias FetchCompletion = @Sendable (_ result: Data?, _ response: URLResponse?, _ error: Error?) -> Void

/// Content fetcher for downloading resources.
public final class ContentFetcher: Sendable {

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch content from a URL with completion handler.
    @discardableResult
    public func fetch(_ url: URL, completion: @escaping FetchCompletion) -> URLSessionTask? {
        let request = URLRequest(url: url)

        let task = session.dataTask(with: request) { data, urlResponse, error in
            completion(data, urlResponse, error)
        }
        task.resume()
        return task
    }

    /// Fetch content from a URL using async/await.
    public func fetch(_ url: URL) async throws -> (Data, URLResponse) {
        let request = URLRequest(url: url)
        return try await session.data(for: request)
    }
}
