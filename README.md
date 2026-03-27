# SwiftHeadlessBrowser

[![CI](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml/badge.svg)](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

A **headless browser** for Swift with **full JavaScript execution** on macOS and Linux.

Controls Chrome/Chromium headless via [Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/) to render JS-heavy websites (React, Next.js, SPAs) and extract structured data.

## Verified Sites

```
ANTHROPIC: id=5023394008 title=Anthropic AI Safety Fellow
ANTHROPIC: id=5062955008 title=Applied Safety Research Engineer, Safeguards
UBER:      id=152401     title=Sr Staff Engineer
UBER:      id=155529     title=Engineering Manager, Competitive Data Platform
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/ShawnBaek/SwiftHeadlessBrowser.git", from: "2.0.0")
]
```

```swift
.target(name: "YourApp", dependencies: ["SwiftHeadlessBrowser"])
```

**Requires Chrome/Chromium installed** on the machine.

---

## Usage

```swift
import SwiftHeadlessBrowser

// Launch Chrome headless and connect
let (browser, process) = try await HeadlessBrowser.withChrome()
defer { BrowserProcessLauncher.terminate(process) }

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

// Execute JavaScript directly
let title: String = try await browser.execute("document.title").execute()
```

---

## Page Load Strategies

```swift
// Wait for load event (default)
HeadlessBrowser.withChrome(waitStrategy: .load)

// Wait for network idle (good for SPAs)
HeadlessBrowser.withChrome(waitStrategy: .networkIdle(idleTime: 0.5))

// Wait for a CSS selector to appear
HeadlessBrowser.withChrome(waitStrategy: .selector("#job-list"))

// Wait for a JS condition
HeadlessBrowser.withChrome(waitStrategy: .jsCondition("window.dataLoaded === true"))
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

## Architecture

```
SwiftHeadlessBrowser
├── HeadlessBrowserCore      — HeadlessBrowser class, BrowserEngine protocol, HTML parsing (SwiftSoup)
└── HeadlessBrowserRemote    — RemoteBrowserEngine: Chrome DevTools Protocol over Foundation WebSocket
```

**Dependencies:** [SwiftSoup](https://github.com/scinfu/SwiftSoup) only. No swift-nio, no Vapor.

---

## How It Works

1. `HeadlessBrowser.withChrome()` launches Chrome in `--headless=new` mode
2. Connects via WebSocket (`URLSessionWebSocketTask`) to Chrome DevTools Protocol
3. `Page.navigate` loads the URL, waits for `Page.loadEventFired`
4. `Runtime.evaluate("document.documentElement.outerHTML")` gets the fully rendered DOM
5. SwiftSoup parses the HTML for element extraction

---

## License

MIT License - See [LICENSE](LICENSE) file.
