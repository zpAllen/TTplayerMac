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
        .target(
            name: "CInflate",
            path: "CInflate",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedLibrary("z")
            ]
        ),
        .executableTarget(
            name: "TTPlayer",
            dependencies: ["CInflate"],
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
