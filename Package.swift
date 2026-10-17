// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TTPlayer",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "TTPlayer",
            targets: ["TTPlayer"]
        )
    ],
    targets: [
        .executableTarget(
            name: "TTPlayer",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
