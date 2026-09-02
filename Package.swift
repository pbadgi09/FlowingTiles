// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FlowingTiles",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "FlowingTiles",
            targets: ["FlowingTiles"]
        )
    ],
    targets: [
        .target(
            name: "FlowingTiles"
        ),
        .testTarget(
            name: "FlowingTilesTests",
            dependencies: ["FlowingTiles"]
        )
    ]
)
