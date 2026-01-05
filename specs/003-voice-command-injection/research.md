# Research: Voice Command Injection

## Overview

This document captures technical research for implementing voice-triggered command injection in the speech-to-text application.

## Problem Statement

When using speech-to-text in terminal contexts, users want to trigger slash commands via voice. However:
1. Transcription isn't always exact ("terraform" may transcribe as "terra form")
2. Commands should only inject in terminal apps, not general text fields
3. Users need configurable command mappings

## Phonetic Matching Algorithms

### Algorithm Comparison

| Algorithm | Pros | Cons | Best For |
|-----------|------|------|----------|
| **Soundex** | Simple, fast, widely available | Limited to first letter + 3 codes, English-centric | Short English names |
| **Double Metaphone** | Handles multiple origins, primary/secondary codes | More complex, still English-optimized | Technical terms, mixed-origin words |
| **Jaro-Winkler** | Good for short strings, handles transpositions | Not phonetic-aware | Typo correction |
| **Levenshtein** | Simple edit distance | No phonetic awareness | Exact typo detection |

### Recommendation: Double Metaphone

Double Metaphone is recommended because:
- Handles technical terms like "terraform", "kubernetes", "speckit" better than Soundex
- Provides primary AND secondary phonetic codes for ambiguous words
- Better international support (Slavic, Germanic, Celtic, Greek, Chinese origins)

### Double Metaphone Implementation in Swift

No native Swift implementation exists. Options:

1. **Port from reference implementation** (C++ → Swift)
   - Lawrence Philips' original code is public domain
   - ~500 lines of code
   - Full control over behavior

2. **Bridge to C/C++ library**
   - Use libphonetix or similar
   - Requires C interop setup
   - More performant for large vocabularies

3. **Simplified custom implementation**
   - Handle most common cases
   - ~200 lines for core algorithm
   - Sufficient for limited command vocabulary

### Simplified Phonetic Rules (for custom implementation)

```
Basic transformations:
- Drop duplicate adjacent letters
- C → K before A,O,U or end; S before E,I,Y
- G → J before E,I,Y (most cases)
- GH → silent at end; F in middle
- PH → F
- TH → 0 (theta sound)
- WH → W at start
- X → KS
- Initial KN, GN, PN → N
- Initial WR → R
- MB at end → M

Example:
"terraform" → T-R-F-R-M
"terra form" → T-R + F-R-M → T-R-F-R-M (match!)
```

## Confidence Scoring Approach

### Word-Level Matching

```
Trigger: "terraform design"
Transcription: "terra form design something"

Step 1: Extract first N words from transcription
  → ["terra", "form", "design", "something"]

Step 2: Generate phonetic codes
  Trigger codes: [TRF, RM] + [TSN]  (terraform + design)
  Trans codes:   [TR] + [FRM] + [TSN] + [SMT0N]

Step 3: Find best alignment
  Match "TRF-RM" to "TR-FRM" (terraform split across words)
  Match "TSN" to "TSN" (design exact)

Step 4: Calculate confidence
  Matched: 2/2 trigger terms = 1.0 base
  Penalty for word split: -0.05
  Final confidence: 0.95
```

### Confidence Thresholds

Recommended defaults:
- **0.95+**: Very high confidence, safe to trigger
- **0.85-0.94**: High confidence, likely intended
- **0.70-0.84**: Medium confidence, could be false positive
- **<0.70**: Low confidence, treat as regular text

Per-command thresholds allow tuning for:
- Common phrases: Lower threshold (more permissive)
- Destructive commands: Higher threshold (more conservative)

## Terminal Detection

### macOS Bundle ID Approach

```swift
func isFocusedAppTerminal() -> Bool {
    guard let frontApp = NSWorkspace.shared.frontmostApplication else {
        return false
    }

    let terminalBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "com.mitchellh.ghostty",
        "net.kovidgoyal.kitty",
        "io.alacritty",
        "com.github.wez.wezterm",
        "com.microsoft.VSCode",  // IDE with integrated terminal
    ]

    return terminalBundleIDs.contains(frontApp.bundleIdentifier ?? "")
}
```

### Edge Case: Integrated Terminals

VS Code and other IDEs have integrated terminals.

**Decision**: Treat VS Code as a terminal app by default. Users frequently use VS Code primarily as a terminal environment (Claude Code, development workflows). The bundle ID approach means commands trigger whenever VS Code is focused, regardless of whether the integrated terminal or editor pane has focus.

This is acceptable because:
- Most VS Code users with this speech-to-text tool are using it for terminal workflows
- False positives in editor panes are low-cost (just get slash command text inserted)
- Users can remove VS Code from terminal_apps list if they prefer

Future enhancement: Use Accessibility API to detect if terminal pane specifically has focus (more complex, defer to v2).

## YAML Configuration

### Schema Design

```yaml
# Version for future migrations
version: 1

# Global feature toggle
enabled: true

# Default confidence threshold (0.0-1.0)
default_threshold: 0.8

# How many words from start of transcription to check
match_first_n_words: 5

# Terminal app bundle IDs (user can add custom)
terminal_apps:
  - com.apple.Terminal
  - com.googlecode.iterm2
  - dev.warp.Warp-Stable

# Command definitions
commands:
  - trigger: "terraform design"      # What user says
    inject: "/speckit.plan"          # What gets inserted
    threshold: 0.85                   # Optional override
    enabled: true                     # Optional, default true
```

### Swift Codable Models

```swift
struct CommandConfig: Codable {
    var version: Int = 1
    var enabled: Bool = true
    var defaultThreshold: Double = 0.8
    var matchFirstNWords: Int = 5
    var terminalApps: [String] = []
    var commands: [CommandTrigger] = []

    enum CodingKeys: String, CodingKey {
        case version, enabled, commands
        case defaultThreshold = "default_threshold"
        case matchFirstNWords = "match_first_n_words"
        case terminalApps = "terminal_apps"
    }
}

struct CommandTrigger: Codable, Identifiable {
    var id: UUID = UUID()
    var trigger: String
    var inject: String
    var threshold: Double?
    var enabled: Bool = true

    enum CodingKeys: String, CodingKey {
        case trigger, inject, threshold, enabled
    }
}
```

### File Location

Standard macOS config location: `~/.config/speech-to-text/commands.yaml`

Alternatives considered:
- `~/Library/Application Support/SpeechToText/` - More macOS-standard but hidden
- `~/Library/Preferences/` - Usually for plist files
- Application bundle - Not user-editable

**Recommendation**: Use `~/.config/` for power-user accessibility while also providing Settings UI for non-technical users.

## Architecture Integration

### New Service: CommandDetectionService

```swift
@MainActor
class CommandDetectionService {
    private var config: CommandConfig
    private let configPath: URL
    private var fileWatcher: DispatchSourceFileSystemObject?

    // Check if terminal is focused
    func isTerminalFocused() -> Bool

    // Process transcription, return modified text if command matched
    func processTranscription(_ text: String) -> String

    // Phonetic matching
    private func matchTrigger(_ trigger: String, in text: String) -> PhoneticMatch?

    // Config management
    func reloadConfig()
    func saveConfig()
}
```

### Integration Point

In `RecordingViewModel.transcribeWithFallback()`:

```swift
let result = try await fluidAudioService.transcribe(samples, sampleRate)

// Command detection (terminal only)
let finalText: String
if commandDetectionService.isEnabled && commandDetectionService.isTerminalFocused() {
    finalText = commandDetectionService.processTranscription(result.text)
} else {
    finalText = result.text
}

try await insertTextWithFallback(finalText)
```

## Performance Considerations

### Phonetic Code Caching

For configured triggers, pre-compute phonetic codes at config load time:

```swift
struct PreparedTrigger {
    let trigger: CommandTrigger
    let phoneticCodes: [[String]]  // Words → codes
    let wordCount: Int
}
```

### Match Order Optimization

Sort triggers by word count (descending) to match longer phrases first:
- "terraform design review" checked before "terraform design"
- Prevents partial matches consuming full phrases

### Benchmarks (estimated)

| Operation | Expected Time |
|-----------|--------------|
| Double Metaphone (single word) | <1ms |
| Match against 10 triggers | <5ms |
| Full pipeline (detect + match + replace) | <10ms |

This is well within the 50ms target after transcription.

## Swift Libraries / Dependencies

### YAML Parsing

**Yams** (recommended): Popular, well-maintained Swift YAML parser
```swift
// Package.swift
.package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
```

### File Watching

Use native `DispatchSource.makeFileSystemObjectSource()` - no external dependency needed.

### Phonetic Algorithms

No Swift package with Double Metaphone found. Options:
1. Custom implementation (~300 lines)
2. Port from reference C++ code
3. Use simpler Soundex (available in some packages but limited)

**Recommendation**: Custom implementation for control and simplicity.

## References

- [Double Metaphone Original Paper](http://www.drdobbs.com/the-double-metaphone-search-algorithm/184401251)
- [Yams Swift YAML Library](https://github.com/jpsim/Yams)
- [NSWorkspace.frontmostApplication](https://developer.apple.com/documentation/appkit/nsworkspace/1532097-frontmostapplication)
- [DispatchSource File Watching](https://developer.apple.com/documentation/dispatch/dispatchsource)
