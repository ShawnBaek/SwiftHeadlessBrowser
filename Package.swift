// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SwiftHeadlessWebKit",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8),
        .visionOS(.v1)
    ],
    products: [
        // Unified product - automatically uses correct engine per platform
        .library(
            name: "SwiftHeadlessWebKit",
            targets: ["SwiftHeadlessWebKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.15.0")
    ],
    targets: [
        // Unified target that re-exports platform-specific modules
        .target(
            name: "SwiftHeadlessWebKit",
            dependencies: [
                "HeadlessBrowserCore",
                "HeadlessBrowserRemote",
                .target(name: "HeadlessBrowserApple", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS]))
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Core cross-platform library
        .target(
            name: "HeadlessBrowserCore",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Apple-specific extensions (WebKit rendering)
        .target(
            name: "HeadlessBrowserApple",
            dependencies: ["HeadlessBrowserCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Remote browser engine (all platforms - full JavaScript support via Chrome DevTools Protocol)
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
        // Tests using Swift Testing framework
        .testTarget(
            name: "HeadlessBrowserCoreTests",
            dependencies: ["HeadlessBrowserCore"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "HeadlessBrowserAppleTests",
            dependencies: ["HeadlessBrowserApple"],
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
