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

        let byId: Result<[HTMLElement], ActionError> = page.findElements(.id("header"))
        if case .success(let els) = byId {
            #expect(els.count == 1)
            #expect(els.first?.text == "Header")
        }

        let byClass: Result<[HTMLElement], ActionError> = page.findElements(.class("link"))
        if case .success(let els) = byClass { #expect(els.count == 2) }

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
            </div>
            <div class="job-card">
                <h3 class="title">Android Engineer</h3>
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

// MARK: - Integration Tests (Lightpanda)

@Suite("Integration Tests", .serialized)
struct IntegrationTests {

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
        let browser = try await HeadlessBrowser.create()
        let url = URL(string: "https://boards.greenhouse.io/anthropic")!
        let page: HTMLPage = try await browser.open(url).execute()

        let jobs = Self.extractJobs(from: page, linkSelector: "a[href*='/jobs/']")
        #expect(!jobs.isEmpty, "Should find at least 1 job on Anthropic Greenhouse")
        for job in jobs.prefix(5) {
            print("ANTHROPIC: id=\(job.id) title=\(job.title)")
        }
    }

    @Test("Spotify (Lever) — extract jobs with id and title")
    func spotifyJobs() async throws {
        let browser = try await HeadlessBrowser.create()
        let url = URL(string: "https://jobs.lever.co/spotify")!
        let page: HTMLPage = try await browser.open(url).execute()

        let jobs = Self.extractJobs(from: page, linkSelector: "a[href*='lever.co/spotify/']")
        #expect(!jobs.isEmpty, "Should find at least 1 job on Spotify Lever")
        for job in jobs.prefix(5) {
            print("SPOTIFY: id=\(job.id) title=\(job.title)")
        }
    }
}
