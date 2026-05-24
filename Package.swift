// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "GitCIScreens",
    platforms: [
        .macOS(.v15),
        .iOS(.v17)
    ],
    products: [
        .library(name: "GitCIScreensCore", targets: ["GitCIScreensCore"]),
        .executable(name: "gitci-screens", targets: ["GitCIScreensCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.6.0")
    ],
    targets: [
        .target(
            name: "GitCIScreensCore"
        ),
        .executableTarget(
            name: "GitCIScreensCLI",
            dependencies: [
                "GitCIScreensCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .testTarget(
            name: "GitCIScreensCoreTests",
            dependencies: ["GitCIScreensCore"]
        )
    ]
)
