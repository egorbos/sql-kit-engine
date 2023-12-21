// swift-tools-version: 5.6

import PackageDescription

let package = Package(
    name: "sql-kit-engine",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6)
    ],
    products: [
        .library(name: "SQLKitEngine", targets: ["SQLKitEngine"]),
    ],
    dependencies: [
        .package(url: "https://github.com/vapor/sql-kit.git", from: "3.28.0"),
        // used in tests
        .package(url: "https://github.com/vapor/sqlite-kit.git", from: "4.4.1"),
    ],
    targets: [
        .target(name: "SQLKitEngine", dependencies: [
            .product(name: "SQLKit", package: "sql-kit"),
        ]),
        .testTarget(name: "SQLKitEngineTests", dependencies: [
            .byName(name: "SQLKitEngine"),
            .product(name: "SQLiteKit", package: "sqlite-kit"),
        ]),
    ]
)
