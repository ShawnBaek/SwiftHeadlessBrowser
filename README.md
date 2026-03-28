# SwiftHeadlessBrowser

[![CI](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml/badge.svg)](https://github.com/ShawnBaek/SwiftHeadlessBrowser/actions/workflows/ci.yml)
[![Swift 6](https://img.shields.io/badge/Swift-6.0+-orange.svg?style=flat)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue.svg?style=flat)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-lightgrey.svg?style=flat)](LICENSE)

A **headless browser** for Swift with **full JavaScript execution** on macOS and Linux.

No Chrome required. Uses [Lightpanda](https://lightpanda.io/) — auto-downloaded on first run.

## Test Results

```
ANTHROPIC: id=5023394008 title=Anthropic AI Safety Fellow
ANTHROPIC: id=5062955008 title=Applied Safety Research Engineer, Safeguards
UBER:      id=153599     title=Data Scientist - Risk
UBER:      id=157663     title=2026 Account Management Intern, Amsterdam
```

9 tests, 4 suites, **2.6 seconds**.

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

---

## Usage

```swift
import SwiftHeadlessBrowser

// Lightpanda auto-downloads on first use (~18MB)
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

### With Chrome (optional)

```swift
let (browser, process) = try await HeadlessBrowser.withChrome()
defer { BrowserProcessLauncher.terminate(process) }

let page: HTMLPage = try await browser.open(url).execute()
let title: String = try await browser.execute("document.title").execute()
```

---

## Page Load Strategies (Chrome only)

```swift
HeadlessBrowser.withChrome(waitStrategy: .load)
HeadlessBrowser.withChrome(waitStrategy: .networkIdle(idleTime: 0.5))
HeadlessBrowser.withChrome(waitStrategy: .selector("#job-list"))
HeadlessBrowser.withChrome(waitStrategy: .jsCondition("window.dataLoaded"))
```

---

## Architecture

```
SwiftHeadlessBrowser
├── HeadlessBrowserCore      — HeadlessBrowser, BrowserEngine protocol, HTML parsing
└── HeadlessBrowserRemote    — LightpandaEngine (default), RemoteBrowserEngine (Chrome CDP)
```

**Dependencies:** [SwiftSoup](https://github.com/scinfu/SwiftSoup) only.

## How It Works

1. `HeadlessBrowser.create()` downloads Lightpanda to `~/.cache/swift-headless-browser/` (first run only)
2. Runs `lightpanda fetch --dump html` as a subprocess — renders full JS
3. SwiftSoup parses the returned HTML for element extraction
4. No WebSocket, no Chrome, no external dependencies

---

## License

MIT License - See [LICENSE](LICENSE) file.
