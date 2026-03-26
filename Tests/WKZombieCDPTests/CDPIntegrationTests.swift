//
// CDPIntegrationTests.swift
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
@testable import WKZombie

// MARK: - CDP Integration Tests (Require Chrome)

/// Integration tests that launch a real Chrome headless browser and load JS-heavy websites.
///
/// These tests require Chrome/Chromium to be installed on the system.
/// Set `SKIP_CDP_TESTS=1` environment variable to skip these tests.
/// Set `CHROME_BIN=/path/to/chrome` to specify a custom Chrome binary.
@Suite("CDP Integration Tests", .serialized)
struct CDPIntegrationTests {

    /// Helper to check if CDP tests should run.
    private static var shouldSkip: Bool {
        ProcessInfo.processInfo.environment["SKIP_CDP_TESTS"] != nil
    }

    /// Helper to launch Chrome and create a WKZombie instance.
    private static func launchBrowser(
        waitStrategy: CDPWaitStrategy = .load,
        timeout: TimeInterval = 30.0
    ) async throws -> (WKZombie, Process) {
        let (browser, process) = try await WKZombie.withChrome(
            name: "CDPTest",
            timeoutInSeconds: timeout,
            waitStrategy: waitStrategy
        )
        return (browser, process)
    }

    // MARK: - Basic Navigation Tests

    @Test("Load example.com and verify HTML content")
    func loadExampleDotCom() async throws {
        guard !Self.shouldSkip else {
            print("CDP_SKIP: SKIP_CDP_TESTS is set")
            return
        }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://example.com")!
        let page: HTMLPage = try await browser.open(url).execute()

        let html = page.data?.toString() ?? ""
        #expect(!html.isEmpty, "Page HTML should not be empty")
        #expect(html.contains("Example Domain"), "Should contain 'Example Domain'")

        // Find the h1 element
        let h1Result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector("h1"))
        if case .success(let h1s) = h1Result {
            #expect(h1s.count == 1)
            #expect(h1s.first?.text == "Example Domain")
        }

        print("CDP_INTEGRATION: example.com loaded successfully (\(html.count) chars)")
    }

    // MARK: - JavaScript Execution Tests

    @Test("Execute JavaScript and get result")
    func executeJavaScript() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        // Load a page first
        let url = URL(string: "https://example.com")!
        let _: HTMLPage = try await browser.open(url).execute()

        // Execute document.title
        let title: JavaScriptResult = try await browser.execute("document.title").execute()
        #expect(title == "Example Domain", "document.title should be 'Example Domain'")

        print("CDP_JS_EXEC: document.title = \(title)")
    }

    @Test("Execute arithmetic JavaScript")
    func executeArithmeticJS() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://example.com")!
        let _: HTMLPage = try await browser.open(url).execute()

        let result: JavaScriptResult = try await browser.execute("1 + 1").execute()
        #expect(result == "2", "1 + 1 should equal 2")

        let complexResult: JavaScriptResult = try await browser.execute(
            "JSON.stringify({a: 1, b: [2, 3]})"
        ).execute()
        #expect(complexResult.contains("\"a\":1") || complexResult.contains("\"a\": 1"),
                "Should return JSON string")

        print("CDP_JS_ARITHMETIC: 1+1=\(result), JSON=\(complexResult)")
    }

    // MARK: - Heavy JavaScript Site Tests

    @Test("Load JavaScript-rendered page and extract dynamic content")
    func loadJSRenderedPage() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser(
            waitStrategy: .load,
            timeout: 45.0
        )
        defer { CDPBrowserLauncher.terminate(process) }

        // Use httpbin.org which returns HTML that we can verify
        let url = URL(string: "https://httpbin.org/html")!
        let page: HTMLPage = try await browser.open(url).execute()

        let html = page.data?.toString() ?? ""
        #expect(!html.isEmpty)

        // httpbin /html returns a page with an h1 tag
        let h1Result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector("h1"))
        if case .success(let elements) = h1Result {
            #expect(!elements.isEmpty, "Should find h1 elements")
            print("CDP_HTTPBIN: Found h1: \(elements.first?.text ?? "none")")
        }

        print("CDP_JS_RENDERED: httpbin.org loaded (\(html.count) chars)")
    }

    @Test("Load page that requires JavaScript for content rendering")
    func loadReactStylePage() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser(
            waitStrategy: .load,
            timeout: 45.0
        )
        defer { CDPBrowserLauncher.terminate(process) }

        // Use a page that injects content via JavaScript
        // We'll verify by executing JS to create DOM content, then reading it
        let url = URL(string: "https://example.com")!
        let _: HTMLPage = try await browser.open(url).execute()

        // Inject dynamic content via JavaScript
        let _: JavaScriptResult = try await browser.execute("""
            const div = document.createElement('div');
            div.id = 'dynamic-content';
            div.textContent = 'JS-Rendered Content';
            document.body.appendChild(div);
            'done'
        """).execute()

        // Verify the dynamic content exists by reading it back with JS
        let dynamicText: JavaScriptResult = try await browser.execute(
            "document.getElementById('dynamic-content')?.textContent ?? ''"
        ).execute()

        #expect(dynamicText == "JS-Rendered Content", "Should read back dynamically created content")
        print("CDP_DYNAMIC: Found JS-injected content: \(dynamicText)")
    }

    // MARK: - PostAction Tests

    @Test("PostAction.wait delays correctly")
    func postActionWait() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://example.com")!
        let start = Date()
        let _: HTMLPage = try await browser.open(then: .wait(1.0))(url).execute()
        let elapsed = Date().timeIntervalSince(start)

        #expect(elapsed >= 0.9, "Should have waited at least ~1 second")
        print("CDP_WAIT: Waited \(String(format: "%.2f", elapsed))s")
    }

    @Test("PostAction.validate waits for JS condition")
    func postActionValidate() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://example.com")!
        let _: HTMLPage = try await browser.open(
            then: .validate("document.readyState === 'complete'")
        )(url).execute()

        // If we get here, validation passed
        print("CDP_VALIDATE: document.readyState === 'complete' passed")
    }

    // MARK: - GitHub Pages Test (JS-Heavy)

    @Test("Load GitHub repository page with JavaScript")
    func loadGitHubPage() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser(
            waitStrategy: .load,
            timeout: 45.0
        )
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://github.com/nicklockwood/SwiftFormat")!

        do {
            let page: HTMLPage = try await browser.open(url).execute()
            let html = page.data?.toString() ?? ""

            #expect(!html.isEmpty, "GitHub page should not be empty")
            #expect(html.count > 1000, "GitHub page should have substantial content")

            // Look for repository-related elements
            let readmeResult: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector("article"))
            if case .success(let articles) = readmeResult {
                print("CDP_GITHUB: Found \(articles.count) article elements")
            }

            // Check for the repo name somewhere in the page
            #expect(html.contains("SwiftFormat"), "Page should contain repo name")

            print("CDP_GITHUB: github.com loaded successfully (\(html.count) chars)")
        } catch {
            print("CDP_GITHUB_ERROR: \(error) (may be rate-limited)")
        }
    }

    // MARK: - Uber Careers Test (Compare with HeadlessEngine)

    @Test("Uber careers page with CDP engine (JS-rendered job listings)")
    func uberCareersWithCDP() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser(
            waitStrategy: .load,
            timeout: 60.0
        )
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://www.uber.com/us/en/careers/list/")!

        do {
            let page: HTMLPage = try await browser.open(
                then: .wait(3.0)
            )(url).execute()

            let html = page.data?.toString() ?? ""
            #expect(!html.isEmpty)

            // Try multiple selectors for job listings
            let selectors = [
                "[data-testid='job-card']",
                ".job-listing",
                "[class*='JobCard']",
                "[class*='job-card']",
                "a[href*='/careers/']",
                "[class*='position']"
            ]

            var totalFound = 0
            for selector in selectors {
                let result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector(selector))
                if case .success(let elements) = result, !elements.isEmpty {
                    totalFound += elements.count
                    print("CDP_UBER: Selector '\(selector)' found \(elements.count) elements")
                }
            }

            print("CDP_UBER: Total elements found: \(totalFound)")
            print("CDP_UBER: HTML length: \(html.count)")
            print("CDP_UBER: Note - CDP engine can render JS content that HeadlessEngine cannot")
        } catch {
            print("CDP_UBER_ERROR: \(error) (may be blocked or require additional wait)")
        }
    }

    // MARK: - Multiple Page Navigation

    @Test("Navigate between multiple pages")
    func multiplePageNavigation() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        // Load first page
        let url1 = URL(string: "https://example.com")!
        let page1: HTMLPage = try await browser.open(url1).execute()
        let html1 = page1.data?.toString() ?? ""
        #expect(html1.contains("Example Domain"))

        // Navigate to second page
        let url2 = URL(string: "https://httpbin.org/html")!
        let page2: HTMLPage = try await browser.open(url2).execute()
        let html2 = page2.data?.toString() ?? ""
        #expect(!html2.isEmpty)
        #expect(html2 != html1, "Second page should be different from first")

        print("CDP_MULTI_NAV: Navigated between 2 pages successfully")
    }

    // MARK: - Current Content (inspect)

    @Test("Inspect returns current page content")
    func inspectCurrentContent() async throws {
        guard !Self.shouldSkip else { return }

        let (browser, process) = try await Self.launchBrowser()
        defer { CDPBrowserLauncher.terminate(process) }

        let url = URL(string: "https://example.com")!
        let _: HTMLPage = try await browser.open(url).execute()

        // Inspect should return the same content
        let inspectedPage: HTMLPage = try await browser.inspect().execute()
        let html = inspectedPage.data?.toString() ?? ""
        #expect(html.contains("Example Domain"))

        print("CDP_INSPECT: inspect() returned current content (\(html.count) chars)")
    }
}
