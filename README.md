# SwiftHeadlessBrowser

[![CI](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml/badge.svg)](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

A **headless web browser** for Swift with **full JavaScript execution** on macOS and Linux.

Uses Chrome/Chromium headless via Chrome DevTools Protocol for server-side rendering of JS-heavy websites (React, Next.js, SPAs).

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/ShawnBaek/SwiftHeadlessBrowser.git", from: "2.0.0")
]
```

```swift
.target(
    name: "YourApp",
    dependencies: ["SwiftHeadlessBrowser"]
)
```

**Requires Chrome/Chromium installed** for JavaScript execution. Without Chrome, HTTP-only mode is available.

---

## Quick Start

### With JavaScript (requires Chrome)

```swift
import SwiftHeadlessBrowser

let (browser, process) = try await HeadlessBrowser.withChrome()
defer { BrowserProcessLauncher.terminate(process) }

// Load JS-heavy page — fully rendered
let page: HTMLPage = try await browser.open(URL(string: "https://example.com")!).execute()

// Execute JavaScript
let title: String = try await browser.execute("document.title").execute()

// Find elements in rendered DOM
let links = page.findElements(.cssSelector("a.product-link"))
```

### HTTP-only (no Chrome needed)

```swift
import SwiftHeadlessBrowser

let browser = HeadlessBrowser()
let page: HTMLPage = try await browser.open(URL(string: "https://example.com")!).execute()
let links = page.findElements(.cssSelector("a[href]"))
```

---

## Page Load Strategies

```swift
// Wait for load event (default)
let (browser, process) = try await HeadlessBrowser.withChrome(waitStrategy: .load)

// Wait for network idle (good for SPAs)
let (browser, process) = try await HeadlessBrowser.withChrome(waitStrategy: .networkIdle(idleTime: 0.5))

// Wait for a specific element
let (browser, process) = try await HeadlessBrowser.withChrome(waitStrategy: .selector("#content"))

// Wait for JS condition
let (browser, process) = try await HeadlessBrowser.withChrome(waitStrategy: .jsCondition("window.dataLoaded === true"))
```

---

## CSS Selectors

| Selector | Example | Description |
|----------|---------|-------------|
| `.id("value")` | `.id("header")` | Find by ID |
| `.class("value")` | `.class("btn")` | Find by class |
| `.name("value")` | `.name("email")` | Find by name attribute |
| `.cssSelector("query")` | `.cssSelector("div.card > a")` | Custom CSS selector |

---

## Architecture

| Module | What it does |
|--------|-------------|
| `HeadlessBrowserCore` | `HeadlessBrowser` class, HTML parsing (SwiftSoup), `HeadlessEngine` (HTTP-only) |
| `HeadlessBrowserRemote` | `RemoteBrowserEngine` — full JS via Chrome DevTools Protocol over WebSocket |

---

## Credits

- HTML parsing by [SwiftSoup](https://github.com/scinfu/SwiftSoup)
- WebSocket by [websocket-kit](https://github.com/vapor/websocket-kit)
- Original HTML navigation patterns inspired by [WKZombie](https://github.com/mkoehnke/WKZombie)

## License

MIT License - See [LICENSE](LICENSE) file.
