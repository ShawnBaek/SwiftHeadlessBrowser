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

    private static var shouldSkip: Bool {
        ProcessInfo.processInfo.environment["SKIP_BROWSER_TESTS"] != nil
    }

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

    @Test("Booking.com jobs — load JS-rendered page, execute JS, extract job titles")
    func bookingJobs() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launch(timeout: 30.0)
        defer { BrowserProcessLauncher.terminate(process) }

        let url = URL(string: "https://jobs.booking.com/booking/jobs")!

        do {
            let page: HTMLPage = try await browser.open(then: .wait(5.0))(url).execute()
            let html = page.data?.toString() ?? ""
            #expect(!html.isEmpty)

            // Execute JS on the loaded page
            let title: JavaScriptResult = try await browser.execute("document.title").execute()
            print("BOOKING: title = \(title)")

            // Extract job listings
            let selectors = [
                "a[href*='/jobs/']",
                "[class*='job']",
                "[class*='Job']",
                "[class*='position']",
                "[class*='card']"
            ]

            var jobs: [(title: String, url: String)] = []
            for selector in selectors {
                let result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector(selector))
                if case .success(let elements) = result {
                    for el in elements.prefix(20) {
                        let text = el.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let href = el.objectForKey("href") ?? ""
                        if !text.isEmpty && text.count < 200 && !jobs.contains(where: { $0.title == text }) {
                            jobs.append((title: text, url: href))
                        }
                    }
                }
            }

            print("BOOKING: \(jobs.count) jobs found, HTML \(html.count) chars")
            for (i, job) in jobs.prefix(5).enumerated() {
                print("  [\(i+1)] \(job.title)")
            }
        } catch {
            print("BOOKING_ERROR: \(error)")
        }
    }

    @Test("Uber careers page — extract job titles")
    func uberCareers() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launch(timeout: 60.0)
        defer { BrowserProcessLauncher.terminate(process) }

        let url = URL(string: "https://www.uber.com/us/en/careers/list/")!

        do {
            let page: HTMLPage = try await browser.open(then: .wait(3.0))(url).execute()
            let html = page.data?.toString() ?? ""
            #expect(!html.isEmpty)

            let selectors = [
                "a[href*='/careers/']",
                "[class*='job-card']",
                "[class*='JobCard']",
                "[data-testid='job-card']"
            ]

            var jobs: [(title: String, url: String)] = []
            for selector in selectors {
                let result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector(selector))
                if case .success(let elements) = result {
                    for el in elements.prefix(10) {
                        let text = el.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                        let href = el.objectForKey("href") ?? ""
                        if !text.isEmpty && text.count < 200 && !jobs.contains(where: { $0.title == text }) {
                            jobs.append((title: text, url: href))
                        }
                    }
                }
            }

            print("UBER: \(jobs.count) job titles found, HTML \(html.count) chars")
            for (i, job) in jobs.prefix(5).enumerated() {
                print("  [\(i+1)] \(job.title)")
            }
        } catch {
            print("UBER_ERROR: \(error)")
        }
    }
}
