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
        .package(url: "https://github.com/scinfu/SwiftSoup.git", from: "2.7.0")
    ],
    targets: [
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
        .target(
            name: "HeadlessBrowserCore",
            dependencies: ["SwiftSoup"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .target(
            name: "HeadlessBrowserRemote",
            dependencies: ["HeadlessBrowserCore"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "SwiftHeadlessBrowserTests",
            dependencies: ["HeadlessBrowserCore", "HeadlessBrowserRemote"]
        )
    ]
)
