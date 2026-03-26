//
// CDPMessage.swift
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

// MARK: - CDP Outgoing Messages

/// A CDP JSON-RPC request sent to the browser.
public struct CDPRequest: Sendable {
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

// MARK: - CDP Incoming Messages

/// Represents any incoming CDP message parsed from WebSocket.
public enum CDPIncoming: Sendable {
    /// A response to a request, matched by `id`.
    case response(CDPResponse)
    /// An event pushed by the browser (no `id`).
    case event(CDPEvent)

    /// Parse a raw JSON Data payload into a CDPIncoming message.
    public static func parse(_ data: Data) throws -> CDPIncoming {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw CDPError.malformedMessage("Expected JSON object")
        }

        // Responses have an "id" field; events do not
        if let id = json["id"] as? Int {
            let result = json["result"] as? [String: Any]
            let error = CDPResponseError.from(json["error"])
            return .response(CDPResponse(id: id, result: result, error: error))
        } else if let method = json["method"] as? String {
            let params = json["params"] as? [String: Any]
            return .event(CDPEvent(method: method, params: params))
        } else {
            throw CDPError.malformedMessage("Message has neither 'id' nor 'method'")
        }
    }
}

/// A CDP response to a previously sent request.
public struct CDPResponse: @unchecked Sendable {
    public let id: Int
    // Result contains JSON-deserialized values from JSONSerialization
    // which produces plist-compatible (Sendable-safe) types
    nonisolated(unsafe) public let result: [String: Any]?
    public let error: CDPResponseError?

    public init(id: Int, result: [String: Any]?, error: CDPResponseError?) {
        self.id = id
        self.result = result
        self.error = error
    }
}

/// A CDP event pushed by the browser.
public struct CDPEvent: @unchecked Sendable {
    public let method: String
    // Params contains JSON-deserialized values
    nonisolated(unsafe) public let params: [String: Any]?

    public init(method: String, params: [String: Any]?) {
        self.method = method
        self.params = params
    }
}

/// An error returned inside a CDP response.
public struct CDPResponseError: Sendable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }

    static func from(_ value: Any?) -> CDPResponseError? {
        guard let dict = value as? [String: Any],
              let code = dict["code"] as? Int,
              let message = dict["message"] as? String else {
            return nil
        }
        return CDPResponseError(code: code, message: message)
    }
}

// MARK: - CDP Errors

/// Errors specific to CDP communication.
public enum CDPError: Error, Sendable, CustomDebugStringConvertible {
    case connectionFailed(String)
    case browserLaunchFailed(String)
    case protocolError(Int, String)
    case disconnected
    case malformedMessage(String)
    case timeout(String)
    case navigationFailed(String)

    public var debugDescription: String {
        switch self {
        case .connectionFailed(let msg): return "CDP Connection Failed: \(msg)"
        case .browserLaunchFailed(let msg): return "CDP Browser Launch Failed: \(msg)"
        case .protocolError(let code, let msg): return "CDP Protocol Error (\(code)): \(msg)"
        case .disconnected: return "CDP Disconnected"
        case .malformedMessage(let msg): return "CDP Malformed Message: \(msg)"
        case .timeout(let msg): return "CDP Timeout: \(msg)"
        case .navigationFailed(let msg): return "CDP Navigation Failed: \(msg)"
        }
    }
}
