# SwiftHeadlessBrowser

[![CI](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml/badge.svg)](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

**A headless browser for Swift** — render JavaScript-heavy websites (React, Next.js, SPAs) and extract structured data. Like Puppeteer or Playwright, but for Swift.

Powered by [Lightpanda](https://lightpanda.io/). **Zero dependencies to install** — the browser engine auto-downloads on first run.

## Why SwiftHeadlessBrowser?

- **Full JavaScript execution** — SPAs, React, Angular, Vue all render completely
- **Zero install** — no Chrome, no Playwright, no `brew install`, no `apt-get`
- **Swift native** — async/await, Sendable, Swift 6 strict concurrency
- **Cross-platform** — macOS and Linux
- **Lightweight** — only dependency is [SwiftSoup](https://github.com/scinfu/SwiftSoup) for HTML parsing
- **Fast** — Lightpanda renders pages in ~1-2 seconds

## Quick Start

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/ShawnBaek/SwiftHeadlessBrowser.git", branch: "master")
]
```

```swift
import SwiftHeadlessBrowser

// Browser auto-downloads on first run (~18MB, cached after)
let browser = try await HeadlessBrowser.create()

// Load any website — JavaScript fully rendered
let page: HTMLPage = try await browser.open(
    URL(string: "https://boards.greenhouse.io/anthropic")!
).execute()

// Extract data with CSS selectors
let links: Result<[HTMLLink], ActionError> = page.findElements(.cssSelector("a[href*='/jobs/']"))
if case .success(let elements) = links {
    for el in elements {
        print("\(el.href ?? "") — \(el.text ?? "")")
    }
}
```

## Real-World Example

Used in production to scrape **4,446 jobs from 15 companies** including Google, Meta, Uber, OpenAI, Spotify, and more:

```
uber         1,434 jobs    (POST API)
openai         878 jobs    (Ashby JSON API)
anthropic      581 jobs    (Greenhouse JSON API)
canva          476 jobs    (SmartRecruiters JSON API)
google         142 jobs    (Lightpanda HTML)
apple           23 jobs    (Lightpanda HTML)
meta            18 jobs    (Lightpanda HTML)
booking         16 jobs    (Lightpanda HTML)
```

See [NativeMobileJobFetcher](https://github.com/ShawnBaek/NativeMobileJobFetcher) for the full implementation.

## CSS Selectors

```swift
page.findElements(.id("header"))                         // by ID
page.findElements(.class("job-card"))                    // by class
page.findElements(.cssSelector("a[href*='/jobs/']"))     // CSS selector
page.findElements(.attribute("data-id", "123"))          // by attribute
page.findElements(.contains("href", "/careers/"))        // attribute contains
page.findElements(.name("email"))                        // by name
```

## How It Works

```
HeadlessBrowser.create()
       │
       ▼
  Downloads Lightpanda binary (first run only, ~18MB)
  Cached at ~/.cache/swift-headless-browser/
       │
       ▼
  browser.open(url).execute()
       │
       ▼
  Runs: lightpanda fetch --dump html <url>
  (Full JavaScript execution in subprocess)
       │
       ▼
  SwiftSoup parses rendered HTML
       │
       ▼
  page.findElements(.cssSelector("..."))
```

No WebSocket. No Chrome. No system dependencies. Just a single binary subprocess.

## Server-Side Swift

Works great with Vapor, Hummingbird, or any server-side Swift framework:

```swift
import Vapor
import SwiftHeadlessBrowser

func routes(_ app: Application) throws {
    app.get("scrape") { req async throws -> String in
        let browser = try await HeadlessBrowser.create()
        let page: HTMLPage = try await browser.open(
            URL(string: req.query[String.self, at: "url"]!)!
        ).execute()

        let titles = page.findElements(.cssSelector("h1"))
        if case .success(let elements) = titles {
            return elements.first?.text ?? "No title"
        }
        return "No results"
    }
}
```

## Requirements

- Swift 6.0+
- macOS 12+ or Linux (Ubuntu 22.04+)
- Internet connection (first run downloads Lightpanda)

## Contributing

Pull requests welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT License — See [LICENSE](LICENSE).
