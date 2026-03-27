//
// RemoteBrowserConnection.swift
//
// Copyright (c) 2025 Shawn Baek
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
import NIOCore
import NIOPosix
import NIOConcurrencyHelpers
import WebSocketKit

/// Thread-safe remote browser WebSocket connection manager.
///
/// Handles sending commands to the remote browser via the Chrome DevTools Protocol,
/// receiving responses (matched by id), and dispatching browser events to subscribers.
///
/// Uses NIO-compatible locking (not an actor) to avoid event loop issues
/// with WebSocketKit's NIOLoopBound callbacks.
public final class RemoteBrowserConnection: @unchecked Sendable {

    // MARK: - Properties

    private let _state = NIOLockedValueBox(ConnectionState())
    private var webSocket: WebSocket?
    private let eventLoopGroup: any EventLoopGroup
    private let ownsEventLoopGroup: Bool

    struct ConnectionState {
        var nextId: Int = 1
        var nextEventWaiterId: Int = 1
        var pendingRequests: [Int: CheckedContinuation<BrowserResponse, any Error>] = [:]
        var eventHandlers: [String: [@Sendable (BrowserEvent) -> Void]] = [:]
        var eventWaiters: [Int: (method: String, handler: @Sendable (BrowserEvent) -> Void)] = [:]
        var isConnected: Bool = false
    }

    // MARK: - Initialization

    /// Creates a new RemoteBrowserConnection.
    /// - Parameter eventLoopGroup: The NIO event loop group to use. If nil, creates a new one.
    public init(eventLoopGroup: (any EventLoopGroup)? = nil) {
        if let group = eventLoopGroup {
            self.eventLoopGroup = group
            self.ownsEventLoopGroup = false
        } else {
            self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            self.ownsEventLoopGroup = true
        }
    }

    // MARK: - Connection

    /// Connect to a remote browser WebSocket endpoint.
    /// - Parameter url: The WebSocket URL (e.g., `ws://127.0.0.1:9222/devtools/page/ABC`).
    public func connect(to url: URL) async throws {
        let isAlreadyConnected = _state.withLockedValue { $0.isConnected }
        guard !isAlreadyConnected else { return }

        let urlString = url.absoluteString

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
            let didResume = NIOLockedValueBox(false)

            WebSocket.connect(
                to: urlString,
                on: eventLoopGroup
            ) { [self] ws in
                // This closure runs ON the event loop — safe to set up NIOLoopBound callbacks here
                self.webSocket = ws
                self._state.withLockedValue { $0.isConnected = true }

                // Set up message handler (must be called on the event loop)
                ws.onText { [weak self] _, text in
                    guard let self, let data = text.data(using: .utf8) else { return }
                    self.handleIncoming(data)
                }

                ws.onClose.whenComplete { [weak self] _ in
                    self?.handleDisconnected()
                }

                let alreadyResumed = didResume.withLockedValue { val in
                    let was = val
                    val = true
                    return was
                }
                if !alreadyResumed {
                    continuation.resume()
                }
            }.whenFailure { error in
                let alreadyResumed = didResume.withLockedValue { val in
                    let was = val
                    val = true
                    return was
                }
                if !alreadyResumed {
                    continuation.resume(throwing: RemoteBrowserError.connectionFailed(error.localizedDescription))
                }
            }
        }
    }

    private func handleDisconnected() {
        let pending = _state.withLockedValue { state -> [CheckedContinuation<BrowserResponse, any Error>] in
            state.isConnected = false
            let continuations = Array(state.pendingRequests.values)
            state.pendingRequests.removeAll()
            return continuations
        }
        webSocket = nil
        for continuation in pending {
            continuation.resume(throwing: RemoteBrowserError.disconnected)
        }
    }

    private func handleIncoming(_ data: Data) {
        do {
            let message = try IncomingMessage.parse(data)
            switch message {
            case .response(let response):
                let continuation = _state.withLockedValue { state in
                    state.pendingRequests.removeValue(forKey: response.id)
                }
                continuation?.resume(returning: response)
            case .event(let event):
                // Fire persistent handlers
                let handlers = _state.withLockedValue { state in
                    state.eventHandlers[event.method] ?? []
                }
                for handler in handlers {
                    handler(event)
                }
                // Fire and remove one-shot waiters
                let matchedWaiters = _state.withLockedValue { state -> [@Sendable (BrowserEvent) -> Void] in
                    var matched: [@Sendable (BrowserEvent) -> Void] = []
                    for (id, waiter) in state.eventWaiters {
                        if waiter.method == event.method {
                            matched.append(waiter.handler)
                            state.eventWaiters.removeValue(forKey: id)
                        }
                    }
                    return matched
                }
                for handler in matchedWaiters {
                    handler(event)
                }
            }
        } catch {
            // Ignore malformed messages
        }
    }

    // MARK: - Sending Commands

    /// Send a command to the remote browser and wait for the response.
    /// - Parameters:
    ///   - method: The Chrome DevTools Protocol method (e.g., "Page.navigate").
    ///   - params: Optional parameters dictionary.
    ///   - timeout: Maximum time to wait for a response.
    /// - Returns: The browser response.
    public func send(
        method: String,
        params: [String: any Sendable]? = nil,
        timeout: TimeInterval = 30.0
    ) async throws -> BrowserResponse {
        let isConn = _state.withLockedValue { $0.isConnected }
        guard let ws = webSocket, isConn else {
            throw RemoteBrowserError.disconnected
        }

        let id = _state.withLockedValue { state -> Int in
            let id = state.nextId
            state.nextId += 1
            return id
        }

        let request = BrowserCommand(id: id, method: method, params: params)
        let jsonData = try request.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        // Register continuation before sending to avoid race
        let response: BrowserResponse = try await withCheckedThrowingContinuation { continuation in
            _state.withLockedValue { state in
                state.pendingRequests[id] = continuation
            }

            let promise = ws.eventLoop.makePromise(of: Void.self)
            ws.send(jsonString, promise: promise)

            promise.futureResult.whenFailure { [weak self] error in
                let cont = self?._state.withLockedValue { state in
                    state.pendingRequests.removeValue(forKey: id)
                }
                cont?.resume(throwing: RemoteBrowserError.connectionFailed(error.localizedDescription))
            }
        }

        if let error = response.error {
            throw RemoteBrowserError.protocolError(error.code, error.message)
        }

        return response
    }

    // MARK: - Event Subscription

    /// Subscribe to browser events of a given method.
    /// - Parameters:
    ///   - method: The browser event method (e.g., "Page.loadEventFired").
    ///   - handler: Callback invoked when the event fires.
    public func on(_ method: String, handler: @escaping @Sendable (BrowserEvent) -> Void) {
        _state.withLockedValue { state in
            state.eventHandlers[method, default: []].append(handler)
        }
    }

    /// Represents a pending event wait that has been registered but not yet awaited.
    /// The waiter is registered synchronously to avoid race conditions.
    public struct EventWaiter: Sendable {
        let stream: AsyncStream<BrowserEvent>
        let waiterId: Int
        let connection: RemoteBrowserConnection

        /// Await the event with a timeout.
        public func wait(timeout: TimeInterval = 30.0) async throws -> BrowserEvent? {
            try await withThrowingTaskGroup(of: BrowserEvent?.self) { group in
                group.addTask {
                    for await event in stream {
                        return event
                    }
                    return nil
                }

                group.addTask { [connection, waiterId] in
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    connection._state.withLockedValue { state in
                        state.eventWaiters.removeValue(forKey: waiterId)
                    }
                    throw RemoteBrowserError.timeout("Timed out waiting for event")
                }

                let result = try await group.next()
                group.cancelAll()
                return result ?? nil
            }
        }
    }

    /// Register a waiter for a browser event synchronously.
    /// Returns an `EventWaiter` that can be awaited later.
    /// This allows registering BEFORE the action that triggers the event.
    ///
    /// Usage:
    /// ```swift
    /// let waiter = connection.expectEvent("Page.loadEventFired")
    /// _ = try await connection.send(method: "Page.navigate", params: [...])
    /// try await waiter.wait(timeout: 30)
    /// ```
    public func expectEvent(_ method: String) -> EventWaiter {
        let (stream, continuation) = AsyncStream<BrowserEvent>.makeStream()
        let waiterId = _state.withLockedValue { state -> Int in
            let id = state.nextEventWaiterId
            state.nextEventWaiterId += 1
            let handler: @Sendable (BrowserEvent) -> Void = { event in
                continuation.yield(event)
                continuation.finish()
            }
            state.eventWaiters[id] = (method: method, handler: handler)
            return id
        }
        return EventWaiter(stream: stream, waiterId: waiterId, connection: self)
    }

    /// Wait for a specific browser event, with timeout.
    ///
    /// NOTE: This has a race condition if called after the action that triggers the event.
    /// Prefer `expectEvent()` + `waiter.wait()` for reliable event waiting.
    @discardableResult
    public func waitForEvent(_ method: String, timeout: TimeInterval = 30.0) async throws -> BrowserEvent? {
        let waiter = expectEvent(method)
        return try await waiter.wait(timeout: timeout)
    }

    // MARK: - Cleanup

    /// Close the WebSocket connection.
    public func disconnect() async {
        if let ws = webSocket {
            try? await ws.close().get()
        }
        _state.withLockedValue { $0.isConnected = false }
        webSocket = nil
    }

    /// Shut down the event loop group if we own it.
    public func shutdown() async {
        await disconnect()
        if ownsEventLoopGroup {
            try? await eventLoopGroup.shutdownGracefully()
        }
    }

    /// Whether the connection is currently active.
    public var connected: Bool {
        _state.withLockedValue { $0.isConnected }
    }
}
