// swift-tools-version: 5.8

import PackageDescription

let package = Package(
    name: "MuMetal",
    platforms: [.iOS(.v15)],
    products: [
        .library(
            name: "MuMetal",
            targets: ["MuMetal"]),
    ],
    dependencies: [
        .package(url: "https://github.com/musesum/MuFlo.git", .branch("main")),
    ],
    targets: [
        .target(
            name: "MuMetal",
            dependencies: [
                .product(name: "MuFlo", package: "MuFlo")],
            resources: [.process("Resources")]),
        .testTarget(
            name: "MuMetalTests",
            dependencies: ["MuMetal"]),
    ]
)
