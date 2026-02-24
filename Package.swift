// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MushafImad",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MushafImad",
            targets: ["MushafImad"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/realm-swift.git", from: "10.49.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MushafImad",
            dependencies: [
                .product(name: "RealmSwift", package: "realm-swift")
            ],
            resources: [
                .process("Media.xcassets"),
                .process("Resources"),
                .copy("quran-images")
            ]
        ),
        .testTarget(
            name: "MushafImadTests",
            dependencies: ["MushafImad"]
        ),
    ]
)
