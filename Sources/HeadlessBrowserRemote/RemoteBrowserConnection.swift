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
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// WebSocket connection to a remote browser via Chrome DevTools Protocol.
///
/// Uses Foundation's URLSessionWebSocketTask for reliable cross-platform
/// WebSocket communication without external dependencies.
public final class RemoteBrowserConnection: @unchecked Sendable {

    // MARK: - Properties

    private struct State {
        var nextId: Int = 1
        var nextEventWaiterId: Int = 1
        var pendingRequests: [Int: CheckedContinuation<BrowserResponse, any Error>] = [:]
        var eventHandlers: [String: [@Sendable (BrowserEvent) -> Void]] = [:]
        var eventWaiters: [Int: (method: String, handler: @Sendable (BrowserEvent) -> Void)] = [:]
        var isConnected: Bool = false
    }

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private let _state: LockedState<State>
    private var receiveTask: Task<Void, Never>?

    /// Simple lock wrapper that avoids NSLock's async restriction.
    private final class LockedState<Value>: @unchecked Sendable {
        private var _value: Value
        private let _lock = NSLock()
        init(_ value: Value) { _value = value }
        func withLock<T>(_ body: (inout Value) -> T) -> T {
            _lock.lock()
            defer { _lock.unlock() }
            return body(&_value)
        }
    }

    // MARK: - Initialization

    public init() {
        self.session = URLSession(configuration: .default)
        self._state = LockedState(State())
    }

    // MARK: - Connection

    /// Connect to a remote browser WebSocket endpoint.
    public func connect(to url: URL) async throws {
        let alreadyConnected = _state.withLock { $0.isConnected }
        guard !alreadyConnected else { return }

        let task = session.webSocketTask(with: url)
        task.resume()

        self.webSocketTask = task
        _state.withLock { $0.isConnected = true }

        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func receiveLoop() async {
        guard let ws = webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    if let data = text.data(using: .utf8) {
                        handleIncoming(data)
                    }
                case .data(let data):
                    handleIncoming(data)
                @unknown default:
                    break
                }
            } catch {
                handleDisconnected()
                break
            }
        }
    }

    private func handleDisconnected() {
        let pending = _state.withLock { state -> [CheckedContinuation<BrowserResponse, any Error>] in
            state.isConnected = false
            let conts = Array(state.pendingRequests.values)
            state.pendingRequests.removeAll()
            return conts
        }
        webSocketTask = nil
        for continuation in pending {
            continuation.resume(throwing: RemoteBrowserError.disconnected)
        }
    }

    private func handleIncoming(_ data: Data) {
        do {
            let message = try IncomingMessage.parse(data)
            switch message {
            case .response(let response):
                let cont = _state.withLock { $0.pendingRequests.removeValue(forKey: response.id) }
                cont?.resume(returning: response)

            case .event(let event):
                let (handlers, waiters) = _state.withLock { state -> ([@Sendable (BrowserEvent) -> Void], [@Sendable (BrowserEvent) -> Void]) in
                    let h = state.eventHandlers[event.method] ?? []
                    var w: [@Sendable (BrowserEvent) -> Void] = []
                    for (id, waiter) in state.eventWaiters where waiter.method == event.method {
                        w.append(waiter.handler)
                        state.eventWaiters.removeValue(forKey: id)
                    }
                    return (h, w)
                }
                for handler in handlers { handler(event) }
                for handler in waiters { handler(event) }
            }
        } catch {
            // Ignore malformed messages
        }
    }

    // MARK: - Sending Commands

    /// Send a command and wait for the response.
    public func send(
        method: String,
        params: [String: any Sendable]? = nil,
        timeout: TimeInterval = 30.0
    ) async throws -> BrowserResponse {
        let (ws, id) = _state.withLock { state -> (URLSessionWebSocketTask?, Int) in
            guard state.isConnected else { return (nil, 0) }
            let id = state.nextId
            state.nextId += 1
            return (webSocketTask, id)
        }

        guard let ws else { throw RemoteBrowserError.disconnected }

        let request = BrowserCommand(id: id, method: method, params: params)
        let jsonData = try request.toJSON()
        let jsonString = String(data: jsonData, encoding: .utf8) ?? ""

        let response: BrowserResponse = try await withCheckedThrowingContinuation { continuation in
            _state.withLock { $0.pendingRequests[id] = continuation }

            Task {
                do {
                    try await ws.send(.string(jsonString))
                } catch {
                    let cont = self._state.withLock { $0.pendingRequests.removeValue(forKey: id) }
                    cont?.resume(throwing: RemoteBrowserError.connectionFailed(error.localizedDescription))
                }
            }
        }

        if let error = response.error {
            throw RemoteBrowserError.protocolError(error.code, error.message)
        }

        return response
    }

    // MARK: - Event Subscription

    /// Subscribe to browser events.
    public func on(_ method: String, handler: @escaping @Sendable (BrowserEvent) -> Void) {
        _state.withLock { $0.eventHandlers[method, default: []].append(handler) }
    }

    /// A registered event waiter that can be awaited.
    public struct EventWaiter: Sendable {
        let stream: AsyncStream<BrowserEvent>
        let waiterId: Int
        let connection: RemoteBrowserConnection

        /// Wait for the event with timeout.
        public func wait(timeout: TimeInterval = 30.0) async throws -> BrowserEvent? {
            try await withThrowingTaskGroup(of: BrowserEvent?.self) { group in
                group.addTask {
                    for await event in stream { return event }
                    return nil
                }
                group.addTask { [connection, waiterId] in
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    connection._state.withLock { $0.eventWaiters.removeValue(forKey: waiterId) }
                    throw RemoteBrowserError.timeout("Timed out waiting for event")
                }
                let result = try await group.next()
                group.cancelAll()
                return result ?? nil
            }
        }
    }

    /// Register a waiter for an event before triggering the action.
    public func expectEvent(_ method: String) -> EventWaiter {
        let (stream, continuation) = AsyncStream<BrowserEvent>.makeStream()
        let waiterId = _state.withLock { state -> Int in
            let id = state.nextEventWaiterId
            state.nextEventWaiterId += 1
            state.eventWaiters[id] = (method: method, handler: { event in
                continuation.yield(event)
                continuation.finish()
            })
            return id
        }
        return EventWaiter(stream: stream, waiterId: waiterId, connection: self)
    }

    /// Wait for a specific event (convenience).
    @discardableResult
    public func waitForEvent(_ method: String, timeout: TimeInterval = 30.0) async throws -> BrowserEvent? {
        try await expectEvent(method).wait(timeout: timeout)
    }

    // MARK: - Cleanup

    /// Close the connection.
    public func disconnect() async {
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        _state.withLock { $0.isConnected = false }
        webSocketTask = nil
    }

    /// Whether the connection is active.
    public var connected: Bool {
        _state.withLock { $0.isConnected }
    }
}
