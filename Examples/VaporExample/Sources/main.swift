//
// main.swift
//
// Copyright (c) 2025 Shawn Baek
//
// Vapor + SwiftHeadlessBrowser Example
// Demonstrates web scraping on Linux servers using Vapor
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

    // Scrape Uber careers page
    app.get("scrape", "uber") { req async throws -> ScrapeResponse in
        let platform: String
        #if os(Linux)
        platform = "Linux"
        #elseif os(macOS)
        platform = "macOS"
        #else
        platform = "Unknown"
        #endif

        // Create browser with Chrome User-Agent
        let engine = HeadlessEngine(
            userAgent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            timeoutInSeconds: 30.0
        )
        let browser = HeadlessBrowser(name: "VaporScraper", engine: engine)

        let careersURL = URL(string: "https://www.uber.com/us/en/careers/list/")!

        let page: HTMLPage = try await browser.open(careersURL).execute()

        let html = page.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        var jobs: [Job] = []

        // Extract jobs using CSS selector
        let jobElements = page.findElements(.cssSelector("a[href*='/careers/']"))
        if case .success(let elements) = jobElements {
            for element in elements.prefix(10) {
                let title = element.text ?? ""
                let href = element.objectForKey("href") ?? ""
                if !title.isEmpty && title.count < 200 {
                    let job = Job(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        url: href
                    )
                    if !jobs.contains(where: { $0.title == job.title }) {
                        jobs.append(job)
                    }
                }
            }
        }

        return ScrapeResponse(
            platform: platform,
            url: careersURL.absoluteString,
            jobsFound: jobs.count,
            jobs: jobs,
            htmlLength: html.count
        )
    }

    // Generic scrape endpoint
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

        let engine = HeadlessEngine(
            userAgent: "Mozilla/5.0 (compatible; SwiftHeadlessBrowser/1.0)",
            timeoutInSeconds: 30.0
        )
        let browser = HeadlessBrowser(name: "VaporScraper", engine: engine)

        let page: HTMLPage = try await browser.open(url).execute()
        let html = page.data.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // Extract all links
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
