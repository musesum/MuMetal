// swift-tools-version: 5.7

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
        .package(url: "https://github.com/musesum/MuPar.git", from: "0.23.0"),
        .package(url: "https://github.com/musesum/MuFlo.git", from: "0.23.0"),
    ],
    targets: [
        .target(
            name: "MuMetal",
            dependencies: [
                .product(name: "MuPar", package: "MuPar"),
                .product(name: "MuFlo", package: "MuFlo"),
            ],
            resources: [.copy("Resources")]),
        .testTarget(
            name: "MuMetalTests",
            dependencies: ["MuMetal"]),
    ]
)
