// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PackageSample",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(url: "https://github.com/417-72KI/octokit.swift", branch: "fix-review"),
    ],
    targets: [
        .executableTarget(
            name: "PackageSample",
            dependencies: [.product(name: "OctoKit", package: "octokit.swift")]),
    ]
)
