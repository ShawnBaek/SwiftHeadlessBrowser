//
// HTMLFetchable.swift
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

// MARK: - Fetchable Protocol

/// Protocol for HTML elements that have downloadable content.
public protocol HTMLFetchable {
    var fetchURL: URL? { get }
    func fetchedContent<T: HTMLFetchableContent>() -> T?
}

// MARK: - Fetched Data Cache

/// Actor for thread-safe storage of fetched data.
public actor FetchedDataCache {
    public static let shared = FetchedDataCache()

    private var storage: [ObjectIdentifier: Data] = [:]

    public func get(for object: AnyObject) -> Data? {
        return storage[ObjectIdentifier(object)]
    }

    public func set(_ data: Data?, for object: AnyObject) {
        if let data = data {
            storage[ObjectIdentifier(object)] = data
        } else {
            storage.removeValue(forKey: ObjectIdentifier(object))
        }
    }
}

// MARK: - Fetchable Default Implementation

extension HTMLFetchable where Self: AnyObject & Sendable {
    /// Async method to get fetched data.
    public func getFetchedDataAsync() async -> Data? {
        return await FetchedDataCache.shared.get(for: self)
    }

    /// Async method to set fetched data.
    public func setFetchedDataAsync(_ data: Data?) async {
        await FetchedDataCache.shared.set(data, for: self)
    }

    /// Async method to get fetched content.
    public func fetchedContentAsync<T: HTMLFetchableContent>() async -> T? {
        if let fetchedData = await getFetchedDataAsync() {
            switch T.instanceFromData(fetchedData) {
            case .success(let value): return value as? T
            case .failure: return nil
            }
        }
        return nil
    }

    public func fetchedContent<T: HTMLFetchableContent>() -> T? {
        // This is now a no-op for backwards compatibility
        // Use fetchedContentAsync instead
        return nil
    }
}

// MARK: - FetchableContentType Protocol

/// Protocol for types that can be created from fetched data.
public protocol HTMLFetchableContent {
    associatedtype ContentType
    static func instanceFromData(_ data: Data) -> Result<ContentType, ActionError>
}

// MARK: - Supported Fetchable Content Types

#if canImport(UIKit)
import UIKit

extension UIImage: HTMLFetchableContent {
    public typealias ContentType = UIImage

    public static func instanceFromData(_ data: Data) -> Result<ContentType, ActionError> {
        if let image = UIImage(data: data) {
            return .success(image)
        }
        return .failure(.transformFailure)
    }
}
#elseif canImport(AppKit)
import AppKit

extension NSImage: HTMLFetchableContent {
    public typealias ContentType = NSImage

    public static func instanceFromData(_ data: Data) -> Result<ContentType, ActionError> {
        if let image = NSImage(data: data) {
            return .success(image)
        }
        return .failure(.transformFailure)
    }
}
#endif

extension Data: HTMLFetchableContent {
    public typealias ContentType = Data

    public static func instanceFromData(_ data: Data) -> Result<ContentType, ActionError> {
        return .success(data)
    }
}
