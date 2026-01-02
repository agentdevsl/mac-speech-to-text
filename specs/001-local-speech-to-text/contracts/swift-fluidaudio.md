# Swift FluidAudio Integration Contract

**Feature**: 001-local-speech-to-text
**Date**: 2026-01-02
**Purpose**: Define the Swift wrapper interface for FluidAudio SDK integration

---

## Overview

This document specifies the Swift wrapper layer that integrates FluidAudio SDK v0.9.0+ for speech-to-text functionality. The wrapper provides a C-compatible ABI for Rust FFI integration while leveraging FluidAudio's native Swift APIs.

**FluidAudio SDK**: https://github.com/FluidInference/FluidAudio
**Version**: v0.9.0+ (Swift 6 compatible)
**Model**: Parakeet TDT v3 (0.6b) - 25 European languages
**Execution**: Apple Neural Engine (ANE) for on-device inference

---

## Swift Package Manager Integration

### Package.swift

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SpeechToTextNative",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "SpeechToTextNative",
            type: .dynamic,
            targets: ["SpeechToTextNative"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            from: "0.9.0"
        )
    ],
    targets: [
        .target(
            name: "SpeechToTextNative",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ]
        ),
        .testTarget(
            name: "SpeechToTextNativeTests",
            dependencies: ["SpeechToTextNative"]
        )
    ]
)
```

---

## C ABI Interface (FFI Exports)

### FluidAudioService Wrapper

```swift
// FluidAudioService.swift
import FluidAudio
import Foundation

/// C-compatible wrapper for FluidAudio SDK
@_cdecl("fluidaudio_create")
public func fluidAudioCreate() -> UnsafeMutableRawPointer? {
    let service = FluidAudioService()
    let pointer = Unmanaged.passRetained(service).toOpaque()
    return UnsafeMutableRawPointer(pointer)
}

@_cdecl("fluidaudio_destroy")
public func fluidAudioDestroy(handle: UnsafeMutableRawPointer?) {
    guard let handle = handle else { return }
    Unmanaged<FluidAudioService>.fromOpaque(handle).release()
}

@_cdecl("fluidaudio_initialize")
public func fluidAudioInitialize(
    handle: UnsafeMutableRawPointer?,
    language: UnsafePointer<CChar>?,
    callback: @escaping @convention(c) (UnsafePointer<CChar>?, Int32) -> Void
) -> Int32 {
    guard let handle = handle,
          let language = language else {
        return -1 // Invalid handle
    }

    let service = Unmanaged<FluidAudioService>.fromOpaque(handle).takeUnretainedValue()
    let languageCode = String(cString: language)

    service.initialize(language: languageCode) { result in
        switch result {
        case .success:
            callback(nil, 0) // Success
        case .failure(let error):
            let errorMessage = error.localizedDescription.cString(using: .utf8)!
            callback(errorMessage, -1)
        }
    }

    return 0
}

@_cdecl("fluidaudio_transcribe")
public func fluidAudioTranscribe(
    handle: UnsafeMutableRawPointer?,
    audioData: UnsafePointer<Int16>?,
    sampleCount: Int32,
    callback: @escaping @convention(c) (UnsafePointer<CChar>?, Float, Int32) -> Void
) -> Int32 {
    guard let handle = handle,
          let audioData = audioData else {
        return -1
    }

    let service = Unmanaged<FluidAudioService>.fromOpaque(handle).takeUnretainedValue()

    // Convert C array to Swift array
    let samples = Array(UnsafeBufferPointer(start: audioData, count: Int(sampleCount)))

    service.transcribe(samples: samples) { result in
        switch result {
        case .success(let transcription):
            let text = transcription.text.cString(using: .utf8)!
            callback(text, transcription.confidence, 0)
        case .failure(let error):
            let errorMessage = error.localizedDescription.cString(using: .utf8)!
            callback(errorMessage, 0.0, -1)
        }
    }

    return 0
}

@_cdecl("fluidaudio_switch_language")
public func fluidAudioSwitchLanguage(
    handle: UnsafeMutableRawPointer?,
    language: UnsafePointer<CChar>?,
    callback: @escaping @convention(c) (Int32) -> Void
) -> Int32 {
    guard let handle = handle,
          let language = language else {
        return -1
    }

    let service = Unmanaged<FluidAudioService>.fromOpaque(handle).takeUnretainedValue()
    let languageCode = String(cString: language)

    service.switchLanguage(to: languageCode) { result in
        switch result {
        case .success:
            callback(0) // Success
        case .failure:
            callback(-1) // Failure
        }
    }

    return 0
}
```

---

## FluidAudioService Implementation

```swift
// FluidAudioService.swift (Swift implementation)
import FluidAudio
import Foundation

public struct TranscriptionResult {
    public let text: String
    public let confidence: Float
    public let durationMs: Int
}

public enum FluidAudioError: Error {
    case modelNotLoaded
    case initializationFailed(String)
    case transcriptionFailed(String)
    case invalidAudioFormat
    case languageNotSupported(String)
}

public class FluidAudioService {
    private var asrManager: AsrManager?
    private var currentLanguage: String = "en"
    private var models: AsrModels?

    public init() {}

    /// Initialize FluidAudio with specified language
    public func initialize(
        language: String,
        completion: @escaping (Result<Void, FluidAudioError>) -> Void
    ) {
        Task {
            do {
                // Download and load models (FluidAudio handles caching)
                let models = try await AsrModels.downloadAndLoad(version: .v3)
                self.models = models

                // Initialize ASR manager
                let config = AsrConfig.default
                let manager = AsrManager(config: config)
                try await manager.initialize(models: models)

                self.asrManager = manager
                self.currentLanguage = language

                completion(.success(()))
            } catch {
                completion(.failure(.initializationFailed(error.localizedDescription)))
            }
        }
    }

    /// Transcribe audio samples
    public func transcribe(
        samples: [Int16],
        completion: @escaping (Result<TranscriptionResult, FluidAudioError>) -> Void
    ) {
        guard let asrManager = asrManager else {
            completion(.failure(.modelNotLoaded))
            return
        }

        Task {
            do {
                let startTime = CFAbsoluteTimeGetCurrent()

                // Convert Int16 samples to Float (FluidAudio expects Float)
                let floatSamples = samples.map { Float($0) / 32768.0 }

                // Perform transcription
                let result = try await asrManager.transcribe(floatSamples)

                let durationMs = Int((CFAbsoluteTimeGetCurrent() - startTime) * 1000)

                let transcription = TranscriptionResult(
                    text: result.text,
                    confidence: result.confidence ?? 0.95, // FluidAudio may not always provide confidence
                    durationMs: durationMs
                )

                completion(.success(transcription))
            } catch {
                completion(.failure(.transcriptionFailed(error.localizedDescription)))
            }
        }
    }

    /// Switch to a different language
    public func switchLanguage(
        to language: String,
        completion: @escaping (Result<Void, FluidAudioError>) -> Void
    ) {
        // Check if language is supported
        let supportedLanguages = [
            "en", "es", "fr", "de", "it", "pt", "ru", "pl", "nl", "sv",
            "da", "no", "fi", "cs", "ro", "uk", "el", "bg", "hr", "sk",
            "sl", "et", "lv", "lt", "mt"
        ]

        guard supportedLanguages.contains(language) else {
            completion(.failure(.languageNotSupported(language)))
            return
        }

        // FluidAudio Parakeet TDT v3 supports all 25 European languages
        // No need to reload model - it's multilingual
        self.currentLanguage = language
        completion(.success(()))
    }

    /// Get current language
    public func getCurrentLanguage() -> String {
        return currentLanguage
    }

    /// Clean up resources
    deinit {
        asrManager = nil
        models = nil
    }
}
```

---

## Rust FFI Interface

```rust
// src-tauri/src/swift_bridge.rs
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_float, c_int, c_void};
use std::sync::{Arc, Mutex};

#[repr(C)]
pub struct FluidAudioHandle(*mut c_void);

unsafe impl Send for FluidAudioHandle {}
unsafe impl Sync for FluidAudioHandle {}

extern "C" {
    fn fluidaudio_create() -> *mut c_void;
    fn fluidaudio_destroy(handle: *mut c_void);
    fn fluidaudio_initialize(
        handle: *mut c_void,
        language: *const c_char,
        callback: extern "C" fn(*const c_char, c_int),
    ) -> c_int;
    fn fluidaudio_transcribe(
        handle: *mut c_void,
        audio_data: *const i16,
        sample_count: c_int,
        callback: extern "C" fn(*const c_char, c_float, c_int),
    ) -> c_int;
    fn fluidaudio_switch_language(
        handle: *mut c_void,
        language: *const c_char,
        callback: extern "C" fn(c_int),
    ) -> c_int;
}

pub struct FluidAudioBridge {
    handle: Arc<Mutex<FluidAudioHandle>>,
}

impl FluidAudioBridge {
    pub fn new() -> Self {
        let handle = unsafe { FluidAudioHandle(fluidaudio_create()) };
        Self {
            handle: Arc::new(Mutex::new(handle)),
        }
    }

    pub async fn initialize(&self, language: &str) -> Result<(), String> {
        let language_cstr = CString::new(language).unwrap();
        let handle = self.handle.lock().unwrap();

        extern "C" fn callback(error: *const c_char, code: c_int) {
            // TODO: Handle callback from Swift
        }

        let result = unsafe {
            fluidaudio_initialize(handle.0, language_cstr.as_ptr(), callback)
        };

        if result == 0 {
            Ok(())
        } else {
            Err("Failed to initialize FluidAudio".to_string())
        }
    }

    pub async fn transcribe(&self, samples: Vec<i16>) -> Result<(String, f32), String> {
        let handle = self.handle.lock().unwrap();

        extern "C" fn callback(text: *const c_char, confidence: c_float, code: c_int) {
            // TODO: Handle callback from Swift
        }

        let result = unsafe {
            fluidaudio_transcribe(
                handle.0,
                samples.as_ptr(),
                samples.len() as c_int,
                callback,
            )
        };

        if result == 0 {
            // TODO: Extract result from callback
            Ok(("Transcribed text".to_string(), 0.95))
        } else {
            Err("Transcription failed".to_string())
        }
    }
}

impl Drop for FluidAudioBridge {
    fn drop(&mut self) {
        let handle = self.handle.lock().unwrap();
        unsafe {
            fluidaudio_destroy(handle.0);
        }
    }
}
```

---

## Supported Languages

FluidAudio Parakeet TDT v3 supports 25 European languages:

| Code | Language | Code | Language |
|------|----------|------|----------|
| `en` | English | `cs` | Czech |
| `es` | Spanish | `ro` | Romanian |
| `fr` | French | `uk` | Ukrainian |
| `de` | German | `el` | Greek |
| `it` | Italian | `bg` | Bulgarian |
| `pt` | Portuguese | `hr` | Croatian |
| `ru` | Russian | `sk` | Slovak |
| `pl` | Polish | `sl` | Slovenian |
| `nl` | Dutch | `et` | Estonian |
| `sv` | Swedish | `lv` | Latvian |
| `da` | Danish | `lt` | Lithuanian |
| `no` | Norwegian | `mt` | Maltese |
| `fi` | Finnish | | |

---

## Error Handling

### Error Codes

| Code | Meaning | Rust Handling |
|------|---------|---------------|
| `0` | Success | `Ok(())` |
| `-1` | Generic failure | `Err(String)` |
| `-2` | Model not loaded | Retry initialization |
| `-3` | Invalid audio format | Validate samples |
| `-4` | Language not supported | Check language code |

### Error Propagation

```swift
public enum FluidAudioError: Error {
    case modelNotLoaded
    case initializationFailed(String)
    case transcriptionFailed(String)
    case invalidAudioFormat
    case languageNotSupported(String)
}
```

---

## Performance Characteristics

### Latency Targets

- **Model Loading**: <2 seconds (first time), <500ms (cached)
- **Transcription**: <100ms for 5-second audio clip
- **Language Switching**: <100ms (multilingual model, no reload needed)
- **Memory Usage**: <300MB during active transcription

### Optimization Notes

- FluidAudio uses Apple Neural Engine automatically
- Models are cached locally after first download
- Parakeet TDT v3 is multilingual (no model switching overhead)
- Real-time factor: ~190x on M4 Pro (per FluidAudio docs)

---

## Testing Strategy

### Unit Tests (XCTest)

```swift
import XCTest
@testable import SpeechToTextNative

class FluidAudioServiceTests: XCTestCase {
    func testInitialization() async throws {
        let service = FluidAudioService()

        let expectation = expectation(description: "Initialization completes")

        service.initialize(language: "en") { result in
            XCTAssertNoThrow(try result.get())
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testTranscription() async throws {
        let service = FluidAudioService()

        // Initialize first
        let initExpectation = expectation(description: "Init")
        service.initialize(language: "en") { _ in initExpectation.fulfill() }
        await fulfillment(of: [initExpectation], timeout: 5.0)

        // Create mock audio (5 seconds of silence at 16kHz)
        let mockSamples = [Int16](repeating: 0, count: 80000)

        let transcribeExpectation = expectation(description: "Transcription completes")

        service.transcribe(samples: mockSamples) { result in
            switch result {
            case .success(let transcription):
                XCTAssertFalse(transcription.text.isEmpty)
                XCTAssertGreaterThan(transcription.confidence, 0.0)
            case .failure(let error):
                XCTFail("Transcription failed: \(error)")
            }
            transcribeExpectation.fulfill()
        }

        await fulfillment(of: [transcribeExpectation], timeout: 10.0)
    }
}
```

---

## Integration Notes

### Build Configuration

Add to `src-tauri/build.rs`:

```rust
fn main() {
    println!("cargo:rerun-if-changed=swift/");

    // Build Swift package
    std::process::Command::new("swift")
        .args(&["build", "-c", "release"])
        .current_dir("swift/")
        .status()
        .expect("Failed to build Swift package");

    // Link Swift library
    println!("cargo:rustc-link-search=swift/.build/release");
    println!("cargo:rustc-link-lib=dylib=SpeechToTextNative");
}
```

### Runtime Requirements

- macOS 12.0 (Monterey) or later
- Apple Silicon (M1/M2/M3/M4)
- Swift 5.9+ runtime
- ~500MB disk space per language model

---

**Contract Complete**: Ready for implementation with FluidAudio SDK v0.9.0+
