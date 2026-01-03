# SpeechToText

A privacy-focused, local-first macOS menu bar application for speech-to-text
capture using the FluidAudio SDK.

**Status**: Alpha (MVP complete, testing in progress)

---

## Features

- **Global Hotkey** (Cmd+Ctrl+Space): Trigger recording from anywhere
- **Local Transcription**: All processing happens on-device using FluidAudio SDK
- **Text Insertion**: Automatically paste transcribed text into the frontmost application
- **Privacy-First**: No cloud services, no data leaves your Mac
- **25+ Languages**: Support for multiple languages via FluidAudio models

---

## Quick Start

### Prerequisites

- macOS 14 (Sonoma) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+

### Setup Code Signing (Recommended)

For persistent permissions across rebuilds:

```bash
# One-time setup
./scripts/setup-signing.sh

# Build the app
./scripts/build-app.sh

# Launch
open build/SpeechToText.app
```

On first launch, grant:

1. **Microphone** permission (dialog prompt)
2. **Accessibility** permission (System Settings > Privacy & Security)

See [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md) for detailed setup instructions.

### Alternative: Xcode Workflow

```bash
open Package.swift
# Build and run in Xcode (Cmd+R)
```

See [docs/XCODE_WORKFLOW.md](docs/XCODE_WORKFLOW.md) for Xcode-specific instructions.

---

## Project Structure

```text
SpeechToText/
├── Sources/
│   ├── SpeechToTextApp/     # App entry point
│   ├── Services/            # Business logic (7 services)
│   ├── Models/              # Data structures (5 models)
│   ├── Views/               # SwiftUI views + ViewModels
│   └── Utilities/           # Extensions and constants
├── Tests/                   # XCTest suite
├── scripts/                 # Build and utility scripts
├── docs/                    # Development documentation
└── specs/                   # Feature specifications
```

---

## Development

### Building

```bash
# Debug build
./scripts/build-app.sh

# Release build
./scripts/build-app.sh --release

# Release + DMG
./scripts/build-app.sh --release --dmg

# Clean build
./scripts/build-app.sh --clean
```

### Testing

```bash
# Run all tests
swift test --parallel

# Run smoke test (macOS only)
./scripts/smoke-test.sh --build

# Check permission status
./scripts/smoke-test.sh --check-permissions
```

### Code Quality

```bash
# SwiftLint
swiftlint

# Pre-commit hooks
pre-commit run --all-files
```

---

## Code Signing

For local development, the app uses a self-signed certificate to ensure macOS
TCC (permissions) persist across rebuilds.

### Why This Matters

Without proper code signing:

- You must re-grant permissions after every rebuild
- macOS treats each build as a new application
- Development becomes tedious

### Quick Setup

```bash
./scripts/setup-signing.sh
```

This creates a self-signed certificate in your login keychain and configures
builds to use it automatically.

For more details, see [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md).

---

## Architecture

- **Language**: Swift 5.9+ with Swift 6 concurrency
- **UI**: SwiftUI + AppKit (menu bar integration)
- **Audio**: AVFoundation (16kHz mono capture)
- **ML/ASR**: FluidAudio SDK (local speech recognition)
- **Testing**: XCTest framework

Key patterns:

- Service layer architecture
- Actor-based concurrency for thread safety
- @Observable for state management
- Protocol-based dependency injection

See [AGENTS.md](AGENTS.md) for detailed development guidelines.

---

## Documentation

| Document | Description |
|----------|-------------|
| [AGENTS.md](AGENTS.md) | Development guidelines and patterns |
| [docs/LOCAL_DEVELOPMENT.md](docs/LOCAL_DEVELOPMENT.md) | Local setup and code signing |
| [docs/XCODE_WORKFLOW.md](docs/XCODE_WORKFLOW.md) | Xcode-specific workflow |
| [docs/CONCURRENCY_PATTERNS.md](docs/CONCURRENCY_PATTERNS.md) | Swift concurrency patterns |

---

## Contributing

1. Fork the repository
2. Create a feature branch
3. Run tests: `swift test --parallel`
4. Run linter: `swiftlint`
5. Submit a pull request

---

## License

[License details here]

---

## Acknowledgments

- FluidAudio SDK for local speech recognition
- Apple for SwiftUI and AVFoundation frameworks
