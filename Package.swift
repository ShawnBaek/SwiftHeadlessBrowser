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
                "WKZombie",
                "WKZombieCDP",
                .target(name: "WKZombieApple", condition: .when(platforms: [.macOS, .iOS, .tvOS, .watchOS, .visionOS])),
                .target(name: "WKZombieLinux", condition: .when(platforms: [.linux]))
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Core cross-platform library
        .target(
            name: "WKZombie",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Apple-specific extensions (WebKit rendering)
        .target(
            name: "WKZombieApple",
            dependencies: ["WKZombie"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // CDP-based engine (all platforms - full JavaScript support)
        .target(
            name: "WKZombieCDP",
            dependencies: [
                "WKZombie",
                .product(name: "WebSocketKit", package: "websocket-kit")
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // Linux-specific extensions
        .target(
            name: "WKZombieLinux",
            dependencies: [
                "WKZombie",
                .target(name: "CWebKit", condition: .when(platforms: [.linux]))
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        // System library for WebKit on Linux
        .systemLibrary(
            name: "CWebKit",
            path: "Sources/CWebKit",
            pkgConfig: "wpe-webkit-1.1",
            providers: [
                .apt(["libwpewebkit-1.1-dev", "libwpe-1.0-dev"]),
                .yum(["wpewebkit-devel", "wpebackend-fdo-devel"])
            ]
        ),
        // Tests using Swift Testing framework
        .testTarget(
            name: "WKZombieTests",
            dependencies: ["WKZombie"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "WKZombieAppleTests",
            dependencies: ["WKZombieApple"],
            resources: [
                .copy("Resources")
            ]
        ),
        .testTarget(
            name: "WKZombieCDPTests",
            dependencies: ["WKZombieCDP"]
        )
    ]
)
