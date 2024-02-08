// swift-tools-version: 5.9

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
        .package(url: "https://github.com/musesum/MuExtensions.git", .branch("main")),
        .package(url: "https://github.com/musesum/MuFlo.git", .branch("main")),
        .package(url: "https://github.com/musesum/MuVision.git", .branch("main")),
    ],
    targets: [
        .target(
            name: "MuMetal",
            dependencies: [
                .product(name: "MuExtensions", package: "MuExtensions"),
                .product(name: "MuFlo", package: "MuFlo"),
                .product(name: "MuVision", package: "MuVision")
            ],
            resources: [.process("Resources")]),
        .testTarget(
            name: "MuMetalTests",
            dependencies: ["MuMetal"]),
    ]
)
