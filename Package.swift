// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftHeadlessBrowser",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftHeadlessBrowser",
            targets: ["SwiftHeadlessBrowser"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.15.0")
    ],
    targets: [
        // Unified target that re-exports all modules
        .target(
            name: "SwiftHeadlessBrowser",
            dependencies: [
                "HeadlessBrowserCore",
                "HeadlessBrowserRemote"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Core cross-platform library (HTML parsing, HeadlessEngine)
        .target(
            name: "HeadlessBrowserCore",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Remote browser engine (full JavaScript support via Chrome DevTools Protocol)
        .target(
            name: "HeadlessBrowserRemote",
            dependencies: [
                "HeadlessBrowserCore",
                .product(name: "WebSocketKit", package: "websocket-kit")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "HeadlessBrowserCoreTests",
            dependencies: ["HeadlessBrowserCore"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "HeadlessBrowserRemoteTests",
            dependencies: ["HeadlessBrowserRemote"]
        )
    ]
)
