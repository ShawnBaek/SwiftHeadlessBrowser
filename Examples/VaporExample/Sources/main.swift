//
// main.swift
//
// Copyright (c) 2025 Shawn Baek
//
// Vapor + SwiftHeadlessBrowser Example
// Demonstrates web scraping with full JavaScript on Linux servers
//

import Vapor
import SwiftHeadlessBrowser

// MARK: - Job Model

struct Job: Content {
    let title: String
    let url: String
}

struct ScrapeResponse: Content {
    let platform: String
    let url: String
    let jobsFound: Int
    let jobs: [Job]
    let htmlLength: Int
}

// MARK: - Routes

func routes(_ app: Application) throws {

    // Health check
    app.get { req async -> String in
        "SwiftHeadlessBrowser + Vapor is running!"
    }

    // Scrape with full JavaScript rendering
    app.get("scrape") { req async throws -> ScrapeResponse in
        guard let urlString = req.query[String.self, at: "url"],
              let url = URL(string: urlString) else {
            throw Abort(.badRequest, reason: "Missing or invalid 'url' query parameter")
        }

        let platform: String
        #if os(Linux)
        platform = "Linux"
        #else
        platform = "macOS"
        #endif

        let (browser, process) = try await HeadlessBrowser.withChrome(
            name: "VaporScraper"
        )
        defer { BrowserProcessLauncher.terminate(process) }

        let page: HTMLPage = try await browser.open(url).execute()
        let html = page.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        var jobs: [Job] = []
        let links = page.findElements(.cssSelector("a[href]"))
        if case .success(let elements) = links {
            for element in elements.prefix(20) {
                let title = element.text ?? ""
                let href = element.objectForKey("href") ?? ""
                if !title.isEmpty && title.count < 200 {
                    jobs.append(Job(title: title, url: href))
                }
            }
        }

        return ScrapeResponse(
            platform: platform,
            url: url.absoluteString,
            jobsFound: jobs.count,
            jobs: jobs,
            htmlLength: html.count
        )
    }
}

// MARK: - Main

@main
struct VaporExample {
    static func main() async throws {
        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)
        defer { Task { try await app.asyncShutdown() } }

        try routes(app)

        try await app.execute()
    }
}
