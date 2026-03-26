//
// Error.swift
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

/// Error types for WKZombie actions
public enum ActionError: Error, Sendable, Equatable, CustomDebugStringConvertible {
    case networkRequestFailure
    case notFound
    case parsingFailure
    case transformFailure
    case snapshotFailure
    case notSupported
    case timeout
    case invalidURL
    case cdpConnectionFailed
    case cdpBrowserLaunchFailed
    case cdpProtocolError(String)
    case cdpDisconnected

    public struct StatusCodes: Sendable {
        public static let success: Int = 200
        public static let error: Int = 500
    }

    public var debugDescription: String {
        switch self {
        case .networkRequestFailure: return "Network Request Failure"
        case .notFound: return "Element Not Found"
        case .parsingFailure: return "Parsing Failure"
        case .transformFailure: return "Transform Failure"
        case .snapshotFailure: return "Snapshot Failure"
        case .notSupported: return "Operation Not Supported on This Platform"
        case .timeout: return "Operation Timed Out"
        case .invalidURL: return "Invalid URL"
        case .cdpConnectionFailed: return "CDP Connection Failed"
        case .cdpBrowserLaunchFailed: return "CDP Browser Launch Failed"
        case .cdpProtocolError(let msg): return "CDP Protocol Error: \(msg)"
        case .cdpDisconnected: return "CDP Disconnected"
        }
    }
}
