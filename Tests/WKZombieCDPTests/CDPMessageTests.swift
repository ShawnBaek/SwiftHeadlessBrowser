//
// CDPMessageTests.swift
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

import Testing
import Foundation
@testable import WKZombieCDP

// MARK: - CDP Message Encoding/Decoding Tests

@Suite("CDP Message Tests")
struct CDPMessageTests {

    // MARK: - CDPRequest Tests

    @Test("CDPRequest serializes to JSON correctly")
    func requestSerialization() throws {
        let request = CDPRequest(id: 1, method: "Page.navigate", params: ["url": "https://example.com"])
        let json = try request.toJSON()
        let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        #expect(dict["id"] as? Int == 1)
        #expect(dict["method"] as? String == "Page.navigate")

        let params = dict["params"] as? [String: Any]
        #expect(params?["url"] as? String == "https://example.com")
    }

    @Test("CDPRequest without params serializes correctly")
    func requestWithoutParams() throws {
        let request = CDPRequest(id: 42, method: "Page.enable")
        let json = try request.toJSON()
        let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        #expect(dict["id"] as? Int == 42)
        #expect(dict["method"] as? String == "Page.enable")
        #expect(dict["params"] == nil)
    }

    @Test("CDPRequest with nested params")
    func requestWithNestedParams() throws {
        let request = CDPRequest(
            id: 3,
            method: "Runtime.evaluate",
            params: [
                "expression": "1 + 1",
                "returnByValue": true,
                "awaitPromise": false
            ]
        )
        let json = try request.toJSON()
        let dict = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        #expect(dict["id"] as? Int == 3)
        let params = dict["params"] as? [String: Any]
        #expect(params?["expression"] as? String == "1 + 1")
        #expect(params?["returnByValue"] as? Bool == true)
        #expect(params?["awaitPromise"] as? Bool == false)
    }

    // MARK: - CDPIncoming Parse Tests

    @Test("Parse CDP response message")
    func parseResponse() throws {
        let json = """
        {"id": 1, "result": {"frameId": "ABC123", "loaderId": "DEF456"}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response, got event")
            return
        }

        #expect(response.id == 1)
        #expect(response.result?["frameId"] as? String == "ABC123")
        #expect(response.result?["loaderId"] as? String == "DEF456")
        #expect(response.error == nil)
    }

    @Test("Parse CDP response with error")
    func parseResponseWithError() throws {
        let json = """
        {"id": 2, "error": {"code": -32600, "message": "Invalid Request"}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response, got event")
            return
        }

        #expect(response.id == 2)
        #expect(response.result == nil)
        #expect(response.error?.code == -32600)
        #expect(response.error?.message == "Invalid Request")
    }

    @Test("Parse CDP event message")
    func parseEvent() throws {
        let json = """
        {"method": "Page.loadEventFired", "params": {"timestamp": 12345.678}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .event(let event) = incoming else {
            Issue.record("Expected event, got response")
            return
        }

        #expect(event.method == "Page.loadEventFired")
        #expect(event.params?["timestamp"] as? Double == 12345.678)
    }

    @Test("Parse CDP event without params")
    func parseEventNoParams() throws {
        let json = """
        {"method": "Page.domContentEventFired"}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .event(let event) = incoming else {
            Issue.record("Expected event, got response")
            return
        }

        #expect(event.method == "Page.domContentEventFired")
        #expect(event.params == nil)
    }

    @Test("Parse CDP response with empty result")
    func parseEmptyResult() throws {
        let json = """
        {"id": 5, "result": {}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response")
            return
        }

        #expect(response.id == 5)
        #expect(response.result != nil)
        #expect(response.result?.isEmpty == true)
    }

    @Test("Parse Runtime.evaluate result with value")
    func parseRuntimeEvaluateResult() throws {
        let json = """
        {"id": 10, "result": {"result": {"type": "string", "value": "Hello World"}}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response")
            return
        }

        let result = response.result?["result"] as? [String: Any]
        #expect(result?["type"] as? String == "string")
        #expect(result?["value"] as? String == "Hello World")
    }

    @Test("Parse Runtime.evaluate result with boolean value")
    func parseRuntimeEvaluateBoolResult() throws {
        let json = """
        {"id": 11, "result": {"result": {"type": "boolean", "value": true}}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response")
            return
        }

        let result = response.result?["result"] as? [String: Any]
        #expect(result?["type"] as? String == "boolean")
        #expect(result?["value"] as? Bool == true)
    }

    @Test("Parse Runtime.evaluate result with numeric value")
    func parseRuntimeEvaluateNumericResult() throws {
        let json = """
        {"id": 12, "result": {"result": {"type": "number", "value": 42, "description": "42"}}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .response(let response) = incoming else {
            Issue.record("Expected response")
            return
        }

        let result = response.result?["result"] as? [String: Any]
        #expect(result?["type"] as? String == "number")
        #expect(result?["value"] as? Int == 42)
    }

    // MARK: - Malformed Message Tests

    @Test("Parse malformed JSON throws error")
    func parseMalformedJSON() {
        let data = "not json".data(using: .utf8)!

        #expect(throws: (any Error).self) {
            try CDPIncoming.parse(data)
        }
    }

    @Test("Parse message without id or method throws error")
    func parseMessageWithoutIdOrMethod() {
        let json = """
        {"someKey": "someValue"}
        """.data(using: .utf8)!

        #expect(throws: CDPError.self) {
            try CDPIncoming.parse(json)
        }
    }

    @Test("Parse non-object JSON throws error")
    func parseNonObjectJSON() {
        let json = "[1, 2, 3]".data(using: .utf8)!

        #expect(throws: CDPError.self) {
            try CDPIncoming.parse(json)
        }
    }

    // MARK: - Network Event Tests

    @Test("Parse Network.requestWillBeSent event")
    func parseNetworkRequestEvent() throws {
        let json = """
        {"method": "Network.requestWillBeSent", "params": {"requestId": "req1", "request": {"url": "https://example.com/api"}}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .event(let event) = incoming else {
            Issue.record("Expected event")
            return
        }

        #expect(event.method == "Network.requestWillBeSent")
        #expect(event.params?["requestId"] as? String == "req1")
    }

    @Test("Parse Network.loadingFinished event")
    func parseNetworkLoadingFinishedEvent() throws {
        let json = """
        {"method": "Network.loadingFinished", "params": {"requestId": "req1", "encodedDataLength": 1024}}
        """.data(using: .utf8)!

        let incoming = try CDPIncoming.parse(json)

        guard case .event(let event) = incoming else {
            Issue.record("Expected event")
            return
        }

        #expect(event.method == "Network.loadingFinished")
        #expect(event.params?["requestId"] as? String == "req1")
    }

    // MARK: - CDPResponseError Tests

    @Test("CDPResponseError.from parses valid error dict")
    func responseErrorFromDict() {
        let dict: [String: Any] = ["code": -32601, "message": "Method not found"]
        let error = CDPResponseError.from(dict)

        #expect(error?.code == -32601)
        #expect(error?.message == "Method not found")
    }

    @Test("CDPResponseError.from returns nil for invalid input")
    func responseErrorFromNil() {
        #expect(CDPResponseError.from(nil) == nil)
        #expect(CDPResponseError.from("not a dict") == nil)
        #expect(CDPResponseError.from(["code": 123]) == nil) // missing message
    }

    // MARK: - CDPError Description Tests

    @Test("CDPError debug descriptions are meaningful")
    func errorDescriptions() {
        let errors: [(CDPError, String)] = [
            (.connectionFailed("timeout"), "CDP Connection Failed: timeout"),
            (.browserLaunchFailed("not found"), "CDP Browser Launch Failed: not found"),
            (.protocolError(-32600, "bad request"), "CDP Protocol Error (-32600): bad request"),
            (.disconnected, "CDP Disconnected"),
            (.malformedMessage("bad json"), "CDP Malformed Message: bad json"),
            (.timeout("30s"), "CDP Timeout: 30s"),
            (.navigationFailed("net::ERR_NAME_NOT_RESOLVED"), "CDP Navigation Failed: net::ERR_NAME_NOT_RESOLVED")
        ]

        for (error, expected) in errors {
            #expect(error.debugDescription == expected)
        }
    }
}

// MARK: - CDPWaitStrategy Tests

@Suite("CDP Wait Strategy Tests")
struct CDPWaitStrategyTests {

    @Test("Wait strategies can be created")
    func createStrategies() {
        // Verify all strategy variants compile and can be created
        let strategies: [CDPWaitStrategy] = [
            .load,
            .domContentLoaded,
            .networkIdle(idleTime: 0.5),
            .selector("#content"),
            .jsCondition("document.readyState === 'complete'"),
            .loadAndNetworkIdle(idleTime: 1.0)
        ]

        #expect(strategies.count == 6)
    }
}
