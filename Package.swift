// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToText",
    platforms: [.macOS(.v14)],
    products: [
        .executable(
            name: "SpeechToText",
            targets: ["SpeechToText"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            branch: "main"
        ),
        .package(
            url: "https://github.com/nalexn/ViewInspector.git",
            from: "0.10.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "SpeechToText",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources",
            exclude: [],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                // Disable strict concurrency checking for Swift 6 compatibility
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking",
                              "-Xfrontend", "-warn-concurrency",
                              "-Xfrontend", "-enable-actor-data-race-checks"])
            ]
        ),
        .testTarget(
            name: "SpeechToTextTests",
            dependencies: [
                "SpeechToText",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests/SpeechToTextTests"
        ),
        .testTarget(
            name: "SpeechToTextIntegrationTests",
            dependencies: [
                "SpeechToText"
            ],
            path: "Tests/SpeechToTextIntegrationTests"
        )
    ]
)
