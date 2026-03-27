//
// RemoteBrowserMessage.swift
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

// MARK: - Remote Browser Outgoing Messages

/// A JSON-RPC request sent to the remote browser via the Chrome DevTools Protocol.
public struct BrowserCommand: Sendable {
    public let id: Int
    public let method: String
    // params contains JSON-serializable values (String, Int, Bool, etc.)
    // which are inherently Sendable but typed as Any for JSONSerialization
    nonisolated(unsafe) public let params: [String: Any]?

    public init(id: Int, method: String, params: [String: any Sendable]? = nil) {
        self.id = id
        self.method = method
        self.params = params
    }

    /// Serializes this request to JSON Data for sending over WebSocket.
    public func toJSON() throws -> Data {
        var dict: [String: Any] = [
            "id": id,
            "method": method
        ]
        if let params = params {
            dict["params"] = params
        }
        return try JSONSerialization.data(withJSONObject: dict, options: [])
    }
}

// MARK: - Remote Browser Incoming Messages

/// Represents any incoming message from the remote browser parsed from WebSocket.
public enum IncomingMessage: Sendable {
    /// A response to a request, matched by `id`.
    case response(BrowserResponse)
    /// An event pushed by the browser (no `id`).
    case event(BrowserEvent)

    /// Parse a raw JSON Data payload into an IncomingMessage.
    public static func parse(_ data: Data) throws -> IncomingMessage {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw RemoteBrowserError.malformedMessage("Expected JSON object")
        }

        // Responses have an "id" field; events do not
        if let id = json["id"] as? Int {
            let result = json["result"] as? [String: Any]
            let error = BrowserResponseError.from(json["error"])
            return .response(BrowserResponse(id: id, result: result, error: error))
        } else if let method = json["method"] as? String {
            let params = json["params"] as? [String: Any]
            return .event(BrowserEvent(method: method, params: params))
        } else {
            throw RemoteBrowserError.malformedMessage("Message has neither 'id' nor 'method'")
        }
    }
}

/// A response from the remote browser to a previously sent request.
public struct BrowserResponse: @unchecked Sendable {
    public let id: Int
    // Result contains JSON-deserialized values from JSONSerialization
    // which produces plist-compatible (Sendable-safe) types
    nonisolated(unsafe) public let result: [String: Any]?
    public let error: BrowserResponseError?

    public init(id: Int, result: [String: Any]?, error: BrowserResponseError?) {
        self.id = id
        self.result = result
        self.error = error
    }
}

/// An event pushed by the remote browser.
public struct BrowserEvent: @unchecked Sendable {
    public let method: String
    // Params contains JSON-deserialized values
    nonisolated(unsafe) public let params: [String: Any]?

    public init(method: String, params: [String: Any]?) {
        self.method = method
        self.params = params
    }
}

/// An error returned inside a remote browser response.
public struct BrowserResponseError: Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    static func from(_ value: Any?) -> BrowserResponseError? {
        guard let dict = value as? [String: Any],
              let code = dict["code"] as? Int,
              let message = dict["message"] as? String else {
            return nil
        }
        return BrowserResponseError(code: code, message: message)
    }
}

// MARK: - Remote Browser Errors

/// Errors specific to remote browser communication via the Chrome DevTools Protocol.
public enum RemoteBrowserError: Error, Sendable, CustomDebugStringConvertible {
    case connectionFailed(String)
    case browserLaunchFailed(String)
    case protocolError(Int, String)
    case disconnected
    case malformedMessage(String)
    case timeout(String)
    case navigationFailed(String)

    public var debugDescription: String {
        switch self {
        case .connectionFailed(let msg): return "Remote Browser Connection Failed: \(msg)"
        case .browserLaunchFailed(let msg): return "Remote Browser Launch Failed: \(msg)"
        case .protocolError(let code, let msg): return "Remote Browser Protocol Error (\(code)): \(msg)"
        case .disconnected: return "Remote Browser Disconnected"
        case .malformedMessage(let msg): return "Remote Browser Malformed Message: \(msg)"
        case .timeout(let msg): return "Remote Browser Timeout: \(msg)"
        case .navigationFailed(let msg): return "Remote Browser Navigation Failed: \(msg)"
        }
    }
}
