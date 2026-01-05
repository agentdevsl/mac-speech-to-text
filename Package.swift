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
        ),
        .package(
            url: "https://github.com/sindresorhus/KeyboardShortcuts",
            from: "2.0.0"
        )
    ],
    targets: [
        .executableTarget(
            name: "SpeechToText",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                "SherpaOnnxSwift"
            ],
            path: "Sources",
            exclude: [],
            resources: [
                .process("Resources/app_logov2.png"),
                .copy("Resources/Models")
            ],
            swiftSettings: [
                .enableUpcomingFeature("BareSlashRegexLiterals"),
                // Disable strict concurrency checking for Swift 6 compatibility
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking",
                              "-Xfrontend", "-warn-concurrency",
                              "-Xfrontend", "-enable-actor-data-race-checks"])
            ]
        ),
        // sherpa-onnx Swift API wrapper target
        .target(
            name: "SherpaOnnxSwift",
            dependencies: ["sherpa_onnx"],
            path: "Resources/sherpa-onnx-swift-api",
            exclude: [
                // Exclude example/demo files that have @main entry points
                "add-punctuation-online.swift",
                "add-punctuations.swift",
                "compute-speaker-embeddings.swift",
                "decode-file-non-streaming.swift",
                "decode-file-sense-voice-with-hr.swift",
                "decode-file-t-one-streaming.swift",
                "decode-file.swift",
                "dolphin-ctc-asr.swift",
                "fire-red-asr.swift",
                "generate-subtitles.swift",
                "keyword-spotting-from-file.swift",
                "medasr-ctc.swift",
                "omnilingual-asr-ctc.swift",
                "speaker-diarization.swift",
                "speech-enhancement-gtcrn.swift",
                "spoken-language-identification.swift",
                "streaming-hlg-decode-file.swift",
                "test-version.swift",
                "tts-kitten-en.swift",
                "tts-kokoro-en.swift",
                "tts-kokoro-zh-en.swift",
                "tts-matcha-en.swift",
                "tts-matcha-zh.swift",
                "tts-vits.swift",
                "wenet-ctc-asr.swift",
                "zipformer-ctc-asr.swift"
            ]
        ),
        // sherpa-onnx xcframework binary target
        .binaryTarget(
            name: "sherpa_onnx",
            path: "Frameworks/sherpa-onnx.xcframework"
        ),
        .testTarget(
            name: "SpeechToTextTests",
            dependencies: [
                "SpeechToText",
                "SherpaOnnxSwift",
                .product(name: "ViewInspector", package: "ViewInspector")
            ],
            path: "Tests/SpeechToTextTests"
        )
    ]
)
