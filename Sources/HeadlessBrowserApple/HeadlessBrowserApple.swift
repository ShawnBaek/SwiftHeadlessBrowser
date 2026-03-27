//
// HeadlessBrowserApple.swift
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

#if canImport(WebKit)
import Foundation
import WebKit
@_exported import HeadlessBrowserCore

// MARK: - Snapshot Types

#if os(iOS) || os(visionOS)
import UIKit
public typealias SnapshotImage = UIImage
#elseif os(macOS)
import AppKit
public typealias SnapshotImage = NSImage
#endif

/// Snapshot class representing a captured page image.
public struct Snapshot: @unchecked Sendable {
    public let image: SnapshotImage?
    public let timestamp: Date

    public init(image: SnapshotImage?) {
        self.image = image
        self.timestamp = Date()
    }
}

public typealias SnapshotHandler = @Sendable (Snapshot) -> Void

// MARK: - WebKit Engine

/// A WebKit-based browser engine for Apple platforms.
/// This engine uses WKWebView for full JavaScript support.
@MainActor
public final class WebKitEngine: @preconcurrency BrowserEngine, @unchecked Sendable {

    private var webView: WKWebView?
    private let processPool: WKProcessPool
    private var _userAgent: UserAgent
    private var _timeoutInSeconds: TimeInterval = 30.0
    private var _loadMediaContent: Bool = true
    private var authenticationHandler: AuthenticationHandler?

    public var userAgent: UserAgent { _userAgent }
    public var timeoutInSeconds: TimeInterval { _timeoutInSeconds }

    public init(processPool: WKProcessPool? = nil, userAgent: UserAgent) {
        self.processPool = processPool ?? WKProcessPool()
        self._userAgent = userAgent
        setupWebView()
    }

    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.processPool = processPool

        #if os(iOS) || os(tvOS) || os(visionOS)
        if !_loadMediaContent {
            config.allowsInlineMediaPlayback = false
        }
        let frame = UIScreen.main.bounds
        #else
        let frame = CGRect(x: 0, y: 0, width: 1024, height: 768)
        #endif

        webView = WKWebView(frame: frame, configuration: config)

        webView?.customUserAgent = userAgent.rawValue

        #if os(iOS) || os(visionOS)
        if let window = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first?.windows.first {
            webView?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            window.addSubview(webView!)
        }
        #elseif os(macOS)
        if let window = NSApplication.shared.windows.first {
            webView?.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
            window.contentView?.addSubview(webView!)
        }
        #endif
    }

    public func openURL(_ url: URL, postAction: PostAction) async throws -> (Data, URL?) {
        guard let webView = webView else {
            throw ActionError.networkRequestFailure
        }

        let request = URLRequest(url: url)
        webView.load(request)

        // Wait for page to load
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Handle post action
        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
        let data = html.data(using: .utf8) ?? Data()
        return (data, webView.url)
    }

    public func execute(_ script: String) async throws -> String {
        guard let webView = webView else {
            throw ActionError.networkRequestFailure
        }

        do {
            let result = try await webView.evaluateJavaScript(script)
            return String(describing: result)
        } catch {
            throw ActionError.networkRequestFailure
        }
    }

    public func executeAndLoad(_ script: String, postAction: PostAction) async throws -> (Data, URL?) {
        guard let webView = webView else {
            throw ActionError.networkRequestFailure
        }

        // Execute the script
        _ = try? await webView.evaluateJavaScript(script)

        // Wait for page to load
        try await Task.sleep(nanoseconds: 1_000_000_000)

        // Handle post action
        if case .wait(let time) = postAction {
            try await Task.sleep(nanoseconds: UInt64(time * 1_000_000_000))
        }

        let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
        let data = html.data(using: .utf8) ?? Data()
        return (data, webView.url)
    }

    public func currentContent() async throws -> (Data, URL?) {
        guard let webView = webView else {
            throw ActionError.notFound
        }

        let html = try await webView.evaluateJavaScript("document.documentElement.outerHTML") as? String ?? ""
        let data = html.data(using: .utf8) ?? Data()
        return (data, webView.url)
    }

    /// Takes a snapshot of the current page.
    #if os(iOS) || os(visionOS)
    public func snapshot() -> Snapshot? {
        guard let webView = webView else { return nil }

        UIGraphicsBeginImageContextWithOptions(webView.bounds.size, true, 0)
        webView.drawHierarchy(in: webView.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return Snapshot(image: image)
    }
    #elseif os(macOS)
    public func snapshot() -> Snapshot? {
        guard let webView = webView else { return nil }

        let rep = webView.bitmapImageRepForCachingDisplay(in: webView.bounds)
        webView.cacheDisplay(in: webView.bounds, to: rep!)
        let image = NSImage(size: webView.bounds.size)
        image.addRepresentation(rep!)

        return Snapshot(image: image)
    }
    #endif

    /// Clears the cache and cookies.
    public func clearCache() {
        let dataStore = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: dataTypes) { records in
            for record in records {
                dataStore.removeData(ofTypes: dataTypes, for: [record]) {}
            }
        }
    }
}

// MARK: - HeadlessBrowserApple Extensions

public extension HeadlessBrowser {
    /// Creates a new HeadlessBrowser instance with WebKit engine.
    ///
    /// - Parameters:
    ///   - name: An optional name/identifier for this instance.
    ///   - processPool: An optional WKProcessPool to share between instances.
    @MainActor
    convenience init(name: String? = nil, processPool: WKProcessPool? = nil, userAgent: UserAgent) {
        self.init(name: name, engine: WebKitEngine(processPool: processPool, userAgent: userAgent))
    }

    /// Submits the specified HTML form.
    ///
    /// - Parameter form: A HTML form.
    /// - Returns: The HeadlessBrowser Action.
    func submit<T: Page>(_ form: HTMLForm) -> Action<T> {
        return submit(then: .none)(form)
    }

    /// Submits the specified HTML form with post action.
    ///
    /// - Parameter postAction: A wait/validation action.
    /// - Returns: A function that takes a form and returns the HeadlessBrowser Action.
    func submit<T: Page>(then postAction: PostAction) -> @Sendable (_ form: HTMLForm) -> Action<T> {
        return { [self] (form: HTMLForm) -> Action<T> in
            return Action(operation: { completion in
                Task {
                    do {
                        guard let script = form.actionScript() else {
                            completion(.failure(.networkRequestFailure))
                            return
                        }
                        let (data, url) = try await self.engine.executeAndLoad(script, postAction: postAction)
                        if let page = T.pageWithData(data, url: url) as? T {
                            completion(.success(page))
                        } else {
                            completion(.failure(.parsingFailure))
                        }
                    } catch let error as ActionError {
                        completion(.failure(error))
                    } catch {
                        completion(.failure(.networkRequestFailure))
                    }
                }
            })
        }
    }

    /// Simulates the click of a HTML link.
    ///
    /// - Parameter link: The HTML link.
    /// - Returns: The HeadlessBrowser Action.
    func click<T: Page>(_ link: HTMLLink) -> Action<T> {
        return click(then: .none)(link)
    }

    /// Simulates the click of a HTML link with post action.
    ///
    /// - Parameter postAction: A wait/validation action.
    /// - Returns: A function that takes a link and returns the HeadlessBrowser Action.
    func click<T: Page>(then postAction: PostAction) -> @Sendable (_ link: HTMLLink) -> Action<T> {
        return { [self] (link: HTMLLink) -> Action<T> in
            return self.redirect(link, postAction: postAction)
        }
    }

    /// Simulates HTMLButton press.
    ///
    /// - Parameter button: The HTML button.
    /// - Returns: The HeadlessBrowser Action.
    func press<T: Page>(_ button: HTMLButton) -> Action<T> {
        return press(then: .none)(button)
    }

    /// Simulates HTMLButton press with post action.
    ///
    /// - Parameter postAction: A wait/validation action.
    /// - Returns: A function that takes a button and returns the HeadlessBrowser Action.
    func press<T: Page>(then postAction: PostAction) -> @Sendable (_ button: HTMLButton) -> Action<T> {
        return { [self] (button: HTMLButton) -> Action<T> in
            return self.redirect(button, postAction: postAction)
        }
    }

    /// Swaps the current page context with an embedded iframe.
    ///
    /// - Parameter iframe: The HTMLFrame (iFrame).
    /// - Returns: The HeadlessBrowser Action.
    func swap<T: Page>(_ iframe: HTMLFrame) -> Action<T> {
        return swap(then: .none)(iframe)
    }

    /// Swaps the current page context with an embedded iframe with post action.
    ///
    /// - Parameter postAction: A wait/validation action.
    /// - Returns: A function that takes an iframe and returns the HeadlessBrowser Action.
    func swap<T: Page>(then postAction: PostAction) -> @Sendable (_ iframe: HTMLFrame) -> Action<T> {
        return { [self] (iframe: HTMLFrame) -> Action<T> in
            return self.redirect(iframe, postAction: postAction)
        }
    }

    /// Internal redirect helper for HTMLRedirectable elements.
    private func redirect<T: Page, U: HTMLRedirectable>(_ redirectable: U, postAction: PostAction) -> Action<T> {
        return Action(operation: { [self] completion in
            Task {
                do {
                    guard let script = redirectable.actionScript() else {
                        completion(.failure(.networkRequestFailure))
                        return
                    }
                    let (data, url) = try await self.engine.executeAndLoad(script, postAction: postAction)
                    if let page = T.pageWithData(data, url: url) as? T {
                        completion(.success(page))
                    } else {
                        completion(.failure(.parsingFailure))
                    }
                } catch let error as ActionError {
                    completion(.failure(error))
                } catch {
                    completion(.failure(.networkRequestFailure))
                }
            }
        })
    }

    /// Clears the cache/cookie data.
    func clearCache() {
        if let engine = engine as? WebKitEngine {
            Task { @MainActor in
                engine.clearCache()
            }
        }
    }
}

// MARK: - Snapshot Extension (iOS only)

#if os(iOS) || os(visionOS)
public extension HeadlessBrowser {
    /// Takes a snapshot of the current page.
    ///
    /// - Parameter element: The element to pass through.
    /// - Returns: The HeadlessBrowser Action.
    func snap<T: Sendable>(_ element: T, handler: @escaping SnapshotHandler) -> Action<T> {
        return Action<T>(operation: { [self] completion in
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second delay
                if let engine = self.engine as? WebKitEngine,
                   let snapshot = engine.snapshot() {
                    handler(snapshot)
                    completion(.success(element))
                } else {
                    completion(.failure(.snapshotFailure))
                }
            }
        })
    }
}
#endif

#endif // canImport(WebKit)
