# SwiftHeadlessBrowser

[![CI](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml/badge.svg)](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

A **headless browser** for Swift with **full JavaScript execution** on macOS and Linux.

Powered by [Lightpanda](https://lightpanda.io/) — auto-downloaded on first run. No Chrome, no system dependencies.

## Test Results

```
ANTHROPIC: id=5023394008 title=Anthropic AI Safety Fellow
ANTHROPIC: id=5062955008 title=Applied Safety Research Engineer, Safeguards
SPOTIFY:   id=31b21dea   title=Apply
SPOTIFY:   id=7426b51c   title=Apply
```

5 tests, 3 suites, **~5 seconds**.

---

## Installation

Add to your `Package.swift` — that's it. **Nothing else to install.**

```swift
dependencies: [
    .package(url: "https://github.com/ShawnBaek/SwiftHeadlessBrowser.git", from: "2.0.0")
]
```

```swift
.target(name: "YourApp", dependencies: ["SwiftHeadlessBrowser"])
```

No `brew install`, no `apt-get`, no Chrome, no system dependencies.
On first run, the Lightpanda browser engine (~18MB) is automatically downloaded to `~/.cache/swift-headless-browser/`. Subsequent runs use the cached binary instantly.

---

## Usage

```swift
import SwiftHeadlessBrowser

let browser = try await HeadlessBrowser.create()

// Load a JS-rendered page
let page: HTMLPage = try await browser.open(
    URL(string: "https://boards.greenhouse.io/anthropic")!
).execute()

// Extract job listings
let links: Result<[HTMLLink], ActionError> = page.findElements(.cssSelector("a[href*='/jobs/']"))
if case .success(let elements) = links {
    for el in elements {
        let id = el.href?.split(separator: "/").last ?? ""
        let title = el.text ?? ""
        print("id=\(id) title=\(title)")
    }
}
```

---

## CSS Selectors

| Selector | Example |
|----------|---------|
| `.id("value")` | `.id("header")` |
| `.class("value")` | `.class("job-card")` |
| `.name("value")` | `.name("email")` |
| `.cssSelector("query")` | `.cssSelector("a[href*='/jobs/']")` |
| `.attribute("key", "val")` | `.attribute("data-id", "123")` |
| `.contains("key", "val")` | `.contains("href", "/careers/")` |

---

## How It Works

1. `HeadlessBrowser.create()` downloads [Lightpanda](https://lightpanda.io/) to `~/.cache/swift-headless-browser/` (first run only, ~18MB)
2. Runs `lightpanda fetch --dump html` as a subprocess — renders full JavaScript
3. [SwiftSoup](https://github.com/scinfu/SwiftSoup) parses the returned HTML for element extraction

12 source files. Only dependency: SwiftSoup.

---

## License

MIT License - See [LICENSE](LICENSE) file.
