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

/// Tests for HTML parsing functionality.
@Suite("HTML Parsing Tests - Static")
struct JavaScriptRenderingTests {

    /// Test basic HTML parsing.
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
