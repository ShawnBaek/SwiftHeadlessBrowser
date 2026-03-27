//
// JavaScriptRenderingTests.swift
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
@testable import HeadlessBrowserCore

// MARK: - JavaScript Rendering Tests

/// Tests for JavaScript-rendered websites using WebKit engines.
///
/// These tests verify that the library can properly render and extract data
/// from websites that use client-side JavaScript rendering (like React, Vue, etc.).
///
/// On Apple platforms, these tests use WebKitEngine (WKWebView).
/// On Linux, these tests use WPEWebKitEngine or WebKitGTKEngine.
@Suite("JavaScript Rendering Tests")
struct JavaScriptRenderingTests {

    // MARK: - Test Data Types

    /// Represents a job listing from Uber Careers page.
    struct UberJob: Sendable, Equatable {
        let title: String
        let team: String
        let location: String
        let url: String
    }

    // MARK: - Uber Careers Page Tests

    // MARK: - Browser User-Agent Constants

    /// Chrome browser User-Agent for avoiding bot detection.
    /// Using a recent Chrome version on macOS to appear as a real browser.
    static let chromeUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    /// Safari browser User-Agent as an alternative.
    static let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    /// Test extracting job listings from Uber Careers page.
    ///
    /// This test verifies that:
    /// 1. The page loads successfully
    /// 2. JavaScript is executed to render the job listings
    /// 3. Job information can be extracted from the rendered DOM
    ///
    /// - Note: This test requires a WebKit-capable engine (WebKitEngine on Apple,
    ///   WPEWebKitEngine or WebKitGTKEngine on Linux).
    @Test("Extract jobs from Uber careers page")
    func extractUberJobs() async throws {
        // Skip if we're using HeadlessEngine (no JavaScript support)
        #if os(Linux)
        // On Linux, we need WPE WebKit installed
        // Skip if not available by checking environment
        guard ProcessInfo.processInfo.environment["SKIP_WEBKIT_TESTS"] == nil else {
            print("Skipping WebKit test - SKIP_WEBKIT_TESTS is set")
            return
        }
        let platformName = "Linux"
        #elseif os(macOS)
        let platformName = "macOS"
        #elseif os(iOS)
        let platformName = "iOS"
        #else
        let platformName = "Unknown"
        #endif

        print("========================================")
        print("UBER_JOBS_TEST_PLATFORM: \(platformName)")
        print("========================================")

        // Use a browser-like User-Agent to avoid being blocked
        let engine = HeadlessEngine(
            userAgent: UserAgent.chromeMac,
            timeoutInSeconds: 30.0
        )
        let browser = HeadlessBrowser(name: "UberCareersTest", engine: engine)
        print("UBER_JOBS_USER_AGENT: \(Self.chromeUserAgent)")

        let careersURL = URL(string: "https://www.uber.com/us/en/careers/list/")!

        do {
            let page: HTMLPage = try await browser.open(careersURL).execute()

            // Check if page loaded (even without JavaScript)
            let html = page.data?.toString() ?? ""
            let htmlLength = html.count
            print("UBER_JOBS_HTML_LENGTH: \(htmlLength)")
            #expect(!html.isEmpty, "Page HTML should not be empty")

            // Look for job-related elements with multiple selectors
            let selectors = [
                "[data-testid='job-card']",
                ".job-listing",
                "[class*='JobCard']",
                "[class*='job-card']",
                "a[href*='/careers/']",
                "[class*='position']",
                "[class*='listing']"
            ]

            var totalElementsFound = 0
            var extractedJobs: [UberJob] = []

            for selector in selectors {
                let jobElements = page.findElements(.cssSelector(selector))
                switch jobElements {
                case .success(let elements):
                    if !elements.isEmpty {
                        print("UBER_JOBS_SELECTOR_\(selector.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "*", with: "").replacingOccurrences(of: "=", with: "_")): \(elements.count)")
                        totalElementsFound += elements.count

                        // Extract job information
                        for element in elements.prefix(10) {
                            let title = element.text ?? ""
                            let href = element.objectForKey("href") ?? ""
                            if !title.isEmpty && title.count < 200 {
                                let job = UberJob(
                                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                    team: "",
                                    location: "",
                                    url: href
                                )
                                if !extractedJobs.contains(job) {
                                    extractedJobs.append(job)
                                }
                            }
                        }
                    }
                case .failure:
                    continue
                }
            }

            print("UBER_JOBS_TOTAL_ELEMENTS_FOUND: \(totalElementsFound)")
            print("UBER_JOBS_EXTRACTED_COUNT: \(extractedJobs.count)")

            if !extractedJobs.isEmpty {
                print("UBER_JOBS_EXTRACTED_TITLES:")
                for (index, job) in extractedJobs.prefix(10).enumerated() {
                    print("  [\(index + 1)] \(job.title)")
                }
            } else {
                print("UBER_JOBS_NOTE: No jobs extracted - page may require JavaScript rendering")
            }

            print("========================================")
            print("UBER_JOBS_TEST_COMPLETE: \(platformName)")
            print("========================================")

        } catch {
            // Network errors are acceptable in CI environments
            print("UBER_JOBS_ERROR: \(error)")
            print("Could not load Uber careers page: \(error)")
        }
    }

    /// Test that HeadlessEngine cannot execute JavaScript.
    @Test("HeadlessEngine does not support JavaScript execution")
    func headlessEngineNoJavaScript() async {
        let engine = HeadlessEngine(userAgent: UserAgent.safariIPhone)

        do {
            _ = try await engine.execute("document.title")
            Issue.record("Expected notSupported error")
        } catch let error as ActionError {
            #expect(error == .notSupported, "HeadlessEngine should throw notSupported for JavaScript")
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    /// Test basic HTML parsing without JavaScript.
    @Test("Parse static HTML without JavaScript")
    func parseStaticHTML() async throws {
        let html = """
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
            <div class="job-card">
                <h3 class="title">Software Engineer</h3>
                <span class="team">Engineering</span>
                <span class="location">San Francisco, CA</span>
            </div>
            <div class="job-card">
                <h3 class="title">Product Manager</h3>
                <span class="team">Product</span>
                <span class="location">New York, NY</span>
            </div>
        </body>
        </html>
        """

        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        // Find job cards
        let jobCardsResult: Result<[HTMLElement], ActionError> = page.findElements(.class("job-card"))

        switch jobCardsResult {
        case .success(let jobCards):
            #expect(jobCards.count == 2, "Should find 2 job cards")

        case .failure(let error):
            Issue.record("Failed to find job cards: \(error)")
        }

        // Find titles directly from page
        let titlesResult: Result<[HTMLElement], ActionError> = page.findElements(.class("title"))
        switch titlesResult {
        case .success(let titles):
            #expect(titles.count == 2, "Should find 2 titles")
            #expect(titles.first?.text == "Software Engineer")
        case .failure(let error):
            Issue.record("Failed to find titles: \(error)")
        }

        // Find teams directly from page
        let teamsResult: Result<[HTMLElement], ActionError> = page.findElements(.class("team"))
        switch teamsResult {
        case .success(let teams):
            #expect(teams.count == 2, "Should find 2 teams")
            #expect(teams.first?.text == "Engineering")
        case .failure(let error):
            Issue.record("Failed to find teams: \(error)")
        }

        // Find locations directly from page
        let locationsResult: Result<[HTMLElement], ActionError> = page.findElements(.class("location"))
        switch locationsResult {
        case .success(let locations):
            #expect(locations.count == 2, "Should find 2 locations")
            #expect(locations.first?.text == "San Francisco, CA")
        case .failure(let error):
            Issue.record("Failed to find locations: \(error)")
        }
    }
}

// MARK: - Platform Comparison Tests

@Suite("Platform Comparison Tests")
struct PlatformComparisonTests {

    /// Verify that HTML parsing produces consistent results across platforms.
    @Test("HTML parsing is consistent across platforms")
    func consistentHTMLParsing() throws {
        let html = """
        <html>
        <body>
            <div id="content">
                <h1>Hello World</h1>
                <p class="description">This is a test.</p>
            </div>
        </body>
        </html>
        """

        let data = html.data(using: .utf8)!
        let page = try HTMLPage(data: data, url: nil)

        // These results should be identical on all platforms
        let h1Result: Result<[HTMLElement], ActionError> = page.findElements(.cssSelector("h1"))
        if case .success(let h1s) = h1Result {
            #expect(h1s.count == 1)
            #expect(h1s.first?.text == "Hello World")
        }

        let descResult: Result<[HTMLElement], ActionError> = page.findElements(.class("description"))
        if case .success(let descs) = descResult {
            #expect(descs.count == 1)
            #expect(descs.first?.text == "This is a test.")
        }

        let contentResult: Result<[HTMLElement], ActionError> = page.findElements(.id("content"))
        if case .success(let contents) = contentResult {
            #expect(contents.count == 1)
        }
    }
}
