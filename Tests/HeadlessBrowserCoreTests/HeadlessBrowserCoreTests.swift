//
// HeadlessBrowserCoreTests.swift
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

import Testing
import Foundation
@testable import HeadlessBrowserCore

// MARK: - Parser Tests

@Suite("HTML Parser Tests")
struct HTMLParserTests {

    @Test("Parse HTML and find elements by ID")
    func parseHTMLFindByID() throws {
        let html = """
        <html>
            <body>
                <div id="test-div">Hello World</div>
            </body>
        </html>
        """
        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        let result: Result<[HTMLElement], ActionError> = page.findElements(.id("test-div"))

        switch result {
        case .success(let elements):
            #expect(elements.count == 1)
            #expect(elements.first?.text == "Hello World")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("Parse HTML and find elements by class")
    func parseHTMLFindByClass() throws {
        let html = """
        <html>
            <body>
                <div class="test-class">Item 1</div>
                <div class="test-class">Item 2</div>
            </body>
        </html>
        """
        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        let result: Result<[HTMLElement], ActionError> = page.findElements(.class("test-class"))

        switch result {
        case .success(let elements):
            #expect(elements.count == 2)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("Parse HTML and find form elements")
    func parseHTMLFindForm() throws {
        let html = """
        <html>
            <body>
                <form id="login-form" name="loginForm" action="/login">
                    <input type="text" name="username" value="testuser">
                    <input type="password" name="password" value="">
                    <button type="submit">Login</button>
                </form>
            </body>
        </html>
        """
        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        let result: Result<[HTMLForm], ActionError> = page.findElements(.id("login-form"))

        switch result {
        case .success(let forms):
            #expect(forms.count == 1)
            let form = forms.first!
            #expect(form.name == "loginForm")
            #expect(form.action == "/login")
            #expect(form["username"] == "testuser")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("Parse HTML and find links")
    func parseHTMLFindLinks() throws {
        let html = """
        <html>
            <body>
                <a href="https://example.com" id="link1">Example</a>
                <a href="https://test.com" id="link2">Test</a>
            </body>
        </html>
        """
        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        let result: Result<[HTMLLink], ActionError> = page.findElements(.id("link1"))

        switch result {
        case .success(let links):
            #expect(links.count == 1)
            let link = links.first!
            #expect(link.href == "https://example.com")
            #expect(link.linkText == "Example")
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("Parse HTML and find table")
    func parseHTMLFindTable() throws {
        let html = """
        <html>
            <body>
                <table id="data-table">
                    <tr><td>Cell 1</td><td>Cell 2</td></tr>
                    <tr><td>Cell 3</td><td>Cell 4</td></tr>
                </table>
            </body>
        </html>
        """
        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        let result: Result<[HTMLTable], ActionError> = page.findElements(.id("data-table"))

        switch result {
        case .success(let tables):
            #expect(tables.count == 1)
            let table = tables.first!
            #expect(table.rows?.count == 2)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }

    @Test("CSS selector query generation")
    func cssQueryGeneration() {
        let idQuery = SearchType<HTMLElement>.id("test").cssQuery()
        #expect(idQuery == "*#test")

        let classQuery = SearchType<HTMLLink>.class("nav").cssQuery()
        #expect(classQuery == "a.nav")

        let nameQuery = SearchType<HTMLForm>.name("form1").cssQuery()
        #expect(nameQuery == "form[name='form1']")
    }
}

// MARK: - Action Tests

@Suite("Action Tests")
struct ActionTests {

    @Test("Action with value succeeds")
    func actionWithValue() async throws {
        let action = Action(value: "Hello")
        let result = try await action.execute()
        #expect(result == "Hello")
    }

    @Test("Action with error fails")
    func actionWithError() async {
        let action = Action<String>(error: .notFound)

        do {
            _ = try await action.execute()
            Issue.record("Expected error but succeeded")
        } catch let error as ActionError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Action map transforms value")
    func actionMap() async throws {
        let action = Action(value: 5)
        let mapped = action.map { $0 * 2 }
        let result = try await mapped.execute()
        #expect(result == 10)
    }

    @Test("Action andThen chains actions")
    func actionAndThen() async throws {
        let action1 = Action(value: "Hello")
        let action2 = action1.andThen { value in
            Action(value: value + " World")
        }
        let result = try await action2.execute()
        #expect(result == "Hello World")
    }

    @Test("Chain operator works")
    func chainOperator() async throws {
        let action1 = Action(value: 10)
        let action2 = action1 >>> { value in Action(value: value + 5) }
        let result = try await action2.execute()
        #expect(result == 15)
    }
}

// MARK: - Headless Engine Tests

@Suite("Headless Engine Tests")
struct HeadlessEngineTests {

    @Test("Headless engine does not support JavaScript")
    func headlessNoJS() async {
        let engine = HeadlessEngine(userAgent: .chromeMac)

        do {
            _ = try await engine.execute("document.title")
            Issue.record("Expected error but succeeded")
        } catch let error as ActionError {
            #expect(error == .notSupported)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Headless engine throws notFound when no content")
    func headlessNoContent() async {
        let engine = HeadlessEngine(userAgent: .safariMac)

        do {
            _ = try await engine.currentContent()
            Issue.record("Expected error but succeeded")
        } catch let error as ActionError {
            #expect(error == .notFound)
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

// MARK: - JSON Tests

@Suite("JSON Parsing Tests")
struct JSONParsingTests {

    struct User: JSONDecodable, Equatable {
        let name: String
        let age: Int

        static func decode(_ json: JSONElement) -> User? {
            guard let name = json["name"] as? String,
                  let age = json["age"] as? Int else {
                return nil
            }
            return User(name: name, age: age)
        }
    }

    @Test("JSON page parsing")
    func jsonPageParsing() throws {
        let json = """
        {"name": "John", "age": 30}
        """
        let data = json.data(using: .utf8)!
        let page = JSONPage(data: data, url: nil)

        #expect(page.content() != nil)
    }

    @Test("JSON decoding")
    func jsonDecoding() throws {
        let json = """
        {"name": "Jane", "age": 25}
        """
        let data = json.data(using: .utf8)!
        let page = JSONPage(data: data, url: nil)

        let result: Result<User, ActionError> = decodeJSON(page.content())

        switch result {
        case .success(let user):
            #expect(user.name == "Jane")
            #expect(user.age == 25)
        case .failure(let error):
            Issue.record("Expected success but got error: \(error)")
        }
    }
}

// MARK: - Search Type Tests

@Suite("SearchType Tests")
struct SearchTypeTests {

    @Test("ID search type generates correct CSS query")
    func idSearchType() {
        let searchType = SearchType<HTMLElement>.id("myId")
        #expect(searchType.cssQuery() == "*#myId")
    }

    @Test("Class search type generates correct CSS query")
    func classSearchType() {
        let searchType = SearchType<HTMLElement>.class("myClass")
        #expect(searchType.cssQuery() == "*.myClass")
    }

    @Test("Name search type generates correct CSS query")
    func nameSearchType() {
        let searchType = SearchType<HTMLElement>.name("myName")
        #expect(searchType.cssQuery() == "*[name='myName']")
    }

    @Test("Attribute search type generates correct CSS query")
    func attributeSearchType() {
        let searchType = SearchType<HTMLElement>.attribute("data-test", "value")
        #expect(searchType.cssQuery() == "*[data-test='value']")
    }

    @Test("Contains search type generates correct CSS query")
    func containsSearchType() {
        let searchType = SearchType<HTMLElement>.contains("href", "example")
        #expect(searchType.cssQuery() == "*[href*='example']")
    }

    @Test("Text search type generates correct CSS query")
    func textSearchType() {
        let searchType = SearchType<HTMLElement>.text("Hello")
        #expect(searchType.cssQuery() == "*:containsOwn(Hello)")
    }
}

// MARK: - PostAction Tests

@Suite("PostAction Tests")
struct PostActionTests {

    @Test("PostAction wait has correct time")
    func postActionWait() {
        let action = PostAction.wait(2.5)
        if case .wait(let time) = action {
            #expect(time == 2.5)
        } else {
            Issue.record("Expected wait action")
        }
    }

    @Test("PostAction validate has correct script")
    func postActionValidate() {
        let action = PostAction.validate("document.ready")
        if case .validate(let script) = action {
            #expect(script == "document.ready")
        } else {
            Issue.record("Expected validate action")
        }
    }

    @Test("PostAction none")
    func postActionNone() {
        let action = PostAction.none
        if case .none = action {
            // Success
        } else {
            Issue.record("Expected none action")
        }
    }
}
