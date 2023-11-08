// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "SwiftlyHttp",
    platforms: [.iOS(.v13), .macOS(.v13)],
    products: [
        .library(
            name: "SwiftlyHttp",
            targets: ["SwiftlyHttp"]),
    ], dependencies: [.package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),],
    targets: [
        .target(
            name: "SwiftlyHttp"),
        .testTarget(
            name: "SwiftlyHttpTests",
            dependencies: ["SwiftlyHttp"]),
    ]
)
