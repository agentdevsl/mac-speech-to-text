# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Project Type**: macOS native application for local speech-to-text capture
**Language**: Swift 5.9+
**Platform**: macOS 14+

## Primary Reference

Please see the root `./AGENTS.md` in this same directory for the main project documentation and guidance.

@/workspace/AGENTS.md

## Additional Component-Specific Guidance

For detailed module-specific implementation guides, also check for AGENTS.md files in subdirectories throughout the project.

These component-specific AGENTS.md files contain targeted guidance for working with those particular areas of the codebase.

## Important: Use Subagents Liberally

When performing any research, concurrent subagents can be used for performance and isolation.
Use parallel tool calls and tasks where possible.

## Quick Reference: Project Structure

```
Sources/
├── SpeechToTextApp/     # App entry point (@main, AppDelegate, AppState)
├── Services/            # Business logic layer (9 services)
├── Models/              # Data structures (5 models)
├── Views/               # SwiftUI components + ViewModels
│   └── Components/      # Reusable UI components
└── Utilities/           # Extensions and constants

Tests/
└── SpeechToTextTests/   # XCTest suite (14 test files)
```

## Key Architectural Patterns

1. **Service Layer Architecture**: All business logic in dedicated service classes
2. **@Observable State Management**: Modern Swift Observation framework (not @StateObject)
3. **Actor-Based Concurrency**: Thread-safe access to ML models and audio buffers
4. **Protocol-Based Testing**: Services use protocols for mockability
5. **Hybrid UI**: SwiftUI for views + AppKit for system integration (menu bar, hotkeys, accessibility)

## Development Workflow

### Building
```bash
swift package resolve      # Resolve dependencies
swift build               # Build from command line
# OR open in Xcode 15.0+
```

### Testing
```bash
swift test                # Run all tests
# OR use Xcode Test Navigator (Cmd+6)
```

### Code Quality
```bash
swiftlint                 # Run linter
pre-commit run --all-files # Run all pre-commit hooks
```

## Swift Version & Features in Use

- **Swift 5.9+** with Swift 6 concurrency flags
- **async/await** for all asynchronous operations
- **Swift actors** for thread-safe concurrency (FluidAudioService, StreamingAudioBuffer)
- **@Observable macro** for reactive state management
- **@MainActor** for UI-bound classes
- **Sendable** conformance for thread-safe data types
- **Structured concurrency** with Task and async let

## Common Commands

```bash
# Development
open SpeechToText.xcodeproj  # Open in Xcode

# Testing
swift test --parallel        # Run tests in parallel

# Code Quality
swiftlint lint --strict      # Lint with zero tolerance
swiftlint autocorrect        # Auto-fix violations

# Git Hooks
pre-commit install           # Install git hooks
pre-commit run --all-files   # Run all hooks manually

# CI/CD
# GitHub Actions runs automatically on push/PR
# See .github/workflows/ci.yml
```

## Technology Stack Quick Reference

| Layer | Technology | Notes |
|-------|-----------|-------|
| Language | Swift 5.9+ | Strict type safety, modern concurrency |
| UI Framework | SwiftUI | Declarative, native macOS UI |
| System Integration | AppKit | Menu bar, hotkeys, accessibility APIs |
| Audio | AVFoundation | AVAudioEngine for 16kHz mono capture |
| ML/ASR | FluidAudio SDK | Local speech-to-text, 25 languages |
| Testing | XCTest | Native Swift testing framework |
| Code Quality | SwiftLint | Static analysis and style enforcement |
| Build System | Swift Package Manager | Dependency management |
| CI/CD | GitHub Actions | Automated testing and quality checks |

## Key Dependencies

- **FluidAudio** (v0.9.0+): Local speech-to-text SDK leveraging Apple Neural Engine
- **AVFoundation**: Audio capture and processing
- **ApplicationServices**: Accessibility APIs for text insertion
- **Carbon**: Global hotkey registration

## Asking Questions

If you need to ask the user a question, use the `AskUserQuestion` tool. This is especially useful during:
- `speckit.clarify` workflows
- Architectural decisions with multiple valid approaches
- Clarifying user preferences or requirements

## Updating AGENTS.md Files

When you discover new information that would be helpful for future development work, please:

- **Update existing AGENTS.md files** when you learn implementation details, debugging insights, or architectural patterns specific to that component
- **Create new AGENTS.md files** in relevant directories when working with areas that don't yet have documentation
- **Add valuable insights** such as:
  - Common pitfalls in Swift/macOS development
  - Actor isolation and concurrency debugging techniques
  - SwiftUI + AppKit integration patterns
  - FluidAudio SDK usage patterns
  - Accessibility API considerations
  - Memory management patterns (especially with Carbon APIs)
  - Testing strategies for async/actor code

## Design Aesthetic: "Warm Minimalism"

This project follows a **Warm Minimalism** design language:
- Frosted glass modals (`.ultraThinMaterial`)
- Amber color palette (AmberLight, AmberPrimary, AmberBright)
- Spring animations (response: 0.5, damping: 0.7)
- Minimal chrome, content-focused
- Floating window level for modals

When creating new UI components, adhere to this aesthetic for consistency.
