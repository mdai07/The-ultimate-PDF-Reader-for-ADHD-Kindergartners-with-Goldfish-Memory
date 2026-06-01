// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "uprakigo",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "PaperReaderCore", targets: ["PaperReaderCore"]),
        .executable(name: "uprakigo", targets: ["AIReaderMac"])
    ],
    targets: [
        .target(name: "PaperReaderCore"),
        .executableTarget(
            name: "AIReaderMac",
            dependencies: ["PaperReaderCore"]
        ),
        .testTarget(
            name: "PaperReaderCoreTests",
            dependencies: ["PaperReaderCore"]
        )
    ]
)
