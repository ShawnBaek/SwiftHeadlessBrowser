import Testing
import Foundation
@testable import HeadlessBrowserCore
@testable import HeadlessBrowserRemote

// MARK: - HTML Parsing

@Suite("HTML Parsing")
struct HTMLParsingTests {

    @Test("Find elements by ID, class, CSS selector")
    func findElements() throws {
        let html = """
        <html><body>
            <div id="header" class="top">Header</div>
            <a href="https://example.com" class="link">Example</a>
            <a href="https://test.com" class="link">Test</a>
        </body></html>
        """
        let page = try HTMLPage(data: html.data(using: .utf8)!, url: nil)

        // By ID
        let byId: Result<[HTMLElement], ActionError> = page.findElements(.id("header"))
        if case .success(let els) = byId {
            #expect(els.count == 1)
            #expect(els.first?.text == "Header")
        }

        // By class
        let byClass: Result<[HTMLElement], ActionError> = page.findElements(.class("link"))
        if case .success(let els) = byClass { #expect(els.count == 2) }

        // By CSS selector
        let byCss: Result<[HTMLLink], ActionError> = page.findElements(.cssSelector("a[href]"))
        if case .success(let links) = byCss {
            #expect(links.count == 2)
            #expect(links.first?.href == "https://example.com")
        }
    }

    @Test("Parse job cards from static HTML")
    func parseJobCards() throws {
        let html = """
        <html><body>
            <div class="job-card">
                <h3 class="title">iOS Engineer</h3>
                <span class="location">San Francisco</span>
            </div>
            <div class="job-card">
                <h3 class="title">Android Engineer</h3>
                <span class="location">New York</span>
            </div>
        </body></html>
        """
        let page = try HTMLPage(data: html.data(using: .utf8)!, url: nil)

        let cards: Result<[HTMLElement], ActionError> = page.findElements(.class("job-card"))
        if case .success(let els) = cards { #expect(els.count == 2) }

        let titles: Result<[HTMLElement], ActionError> = page.findElements(.class("title"))
        if case .success(let els) = titles {
            #expect(els.count == 2)
            #expect(els[0].text == "iOS Engineer")
            #expect(els[1].text == "Android Engineer")
        }
    }

    @Test("Parse forms and tables")
    func parseFormsAndTables() throws {
        let html = """
        <html><body>
            <form id="login" name="loginForm" action="/login">
                <input type="text" name="username" value="user1">
            </form>
            <table id="data"><tr><td>A</td><td>B</td></tr></table>
        </body></html>
        """
        let page = try HTMLPage(data: html.data(using: .utf8)!, url: nil)

        let forms: Result<[HTMLForm], ActionError> = page.findElements(.id("login"))
        if case .success(let f) = forms {
            #expect(f.first?.name == "loginForm")
            #expect(f.first?["username"] == "user1")
        }

        let tables: Result<[HTMLTable], ActionError> = page.findElements(.id("data"))
        if case .success(let t) = tables { #expect(t.first?.rows?.count == 1) }
    }
}

// MARK: - Actions

@Suite("Actions")
struct ActionTests {

    @Test("Action value, error, map, chain")
    func actionOperations() async throws {
        let val = try await Action(value: "hello").execute()
        #expect(val == "hello")

        let mapped = try await Action(value: 5).map { $0 * 2 }.execute()
        #expect(mapped == 10)

        let chained = try await (Action(value: 10) >>> { Action(value: $0 + 5) }).execute()
        #expect(chained == 15)

        do {
            _ = try await Action<String>(error: .notFound).execute()
            Issue.record("Expected error")
        } catch let e as ActionError {
            #expect(e == .notFound)
        }
    }
}

// MARK: - Protocol Messages

@Suite("Protocol Messages")
struct ProtocolMessageTests {

    @Test("BrowserCommand serializes correctly")
    func commandSerialization() throws {
        let cmd = BrowserCommand(id: 1, method: "Page.navigate", params: ["url": "https://example.com"])
        let dict = try JSONSerialization.jsonObject(with: cmd.toJSON()) as! [String: Any]
        #expect(dict["id"] as? Int == 1)
        #expect(dict["method"] as? String == "Page.navigate")
        #expect((dict["params"] as? [String: Any])?["url"] as? String == "https://example.com")
    }

    @Test("Parse response and event messages")
    func parseMessages() throws {
        // Response
        let resp = try IncomingMessage.parse("""
        {"id": 1, "result": {"frameId": "ABC"}}
        """.data(using: .utf8)!)
        if case .response(let r) = resp {
            #expect(r.id == 1)
            #expect(r.result?["frameId"] as? String == "ABC")
        }

        // Event
        let evt = try IncomingMessage.parse("""
        {"method": "Page.loadEventFired", "params": {"timestamp": 123.4}}
        """.data(using: .utf8)!)
        if case .event(let e) = evt {
            #expect(e.method == "Page.loadEventFired")
        }

        // Error response
        let err = try IncomingMessage.parse("""
        {"id": 2, "error": {"code": -32600, "message": "Bad request"}}
        """.data(using: .utf8)!)
        if case .response(let r) = err {
            #expect(r.error?.code == -32600)
        }
    }

    @Test("Malformed JSON throws error")
    func malformedJSON() {
        #expect(throws: (any Error).self) { try IncomingMessage.parse("not json".data(using: .utf8)!) }
        #expect(throws: RemoteBrowserError.self) { try IncomingMessage.parse("{}".data(using: .utf8)!) }
    }
}

// MARK: - Integration Tests (require Chrome)

@Suite("Integration Tests", .serialized)
struct IntegrationTests {

    private static func launch(
        waitStrategy: PageLoadStrategy = .load,
        timeout: TimeInterval = 30.0
    ) async throws -> (HeadlessBrowser, Process) {
        try await HeadlessBrowser.withChrome(
            name: "Test",
            timeoutInSeconds: timeout,
            waitStrategy: waitStrategy
        )
    }

    struct Job {
        let id: String
        let title: String
    }

    private static func extractJobs(from page: HTMLPage, linkSelector: String) -> [Job] {
        let links: Result<[HTMLLink], ActionError> = page.findElements(.cssSelector(linkSelector))
        var jobs: [Job] = []
        if case .success(let elements) = links {
            for el in elements {
                let href = el.href ?? ""
                let title = el.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let id = href.split(separator: "/").last.map(String.init) ?? ""
                if !title.isEmpty && !id.isEmpty && !jobs.contains(where: { $0.id == id }) {
                    jobs.append(Job(id: id, title: title))
                }
            }
        }
        return jobs
    }

    @Test("Anthropic (Greenhouse) — extract jobs with id and title")
    func anthropicJobs() async throws {
        let (browser, process) = try await Self.launch(timeout: 30.0)
        defer { BrowserProcessLauncher.terminate(process) }

        let url = URL(string: "https://boards.greenhouse.io/anthropic")!
        let page: HTMLPage = try await browser.open(then: .wait(5.0))(url).execute()

        let jobs = Self.extractJobs(from: page, linkSelector: "a[href*='/jobs/']")
        #expect(!jobs.isEmpty, "Should find at least 1 job on Anthropic Greenhouse")
        for job in jobs.prefix(5) {
            print("ANTHROPIC: id=\(job.id) title=\(job.title)")
        }
    }

    @Test("Uber — extract jobs with id and title")
    func uberCareers() async throws {
        let (browser, process) = try await Self.launch(timeout: 30.0)
        defer { BrowserProcessLauncher.terminate(process) }

        let url = URL(string: "https://www.uber.com/us/en/careers/list/")!
        let page: HTMLPage = try await browser.open(then: .wait(8.0))(url).execute()

        let jobs = Self.extractJobs(from: page, linkSelector: "a[href*='/careers/']")
        #expect(!jobs.isEmpty, "Should find at least 1 job on Uber")
        for job in jobs.prefix(5) {
            print("UBER: id=\(job.id) title=\(job.title)")
        }
    }
}
