# Implementation Plan: Permission and Code Signing for Local Development

**Branch**: `002-permission-signing` | **Date**: 2026-01-03 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-permission-signing/spec.md`
**Issue**: #10 - Fix permission and code signing issues for local development

---

## Summary

This feature addresses the root cause of permission persistence failures during
local macOS development. The core problem is that ad-hoc code signing generates
a new identity per build, causing macOS TCC to treat each rebuild as a new
application requiring fresh permission grants.

The solution implements:

1. A self-signed certificate workflow for consistent code signing identity
2. Enhanced build scripts with identity validation and clear warnings
3. Comprehensive documentation for both CLI and Xcode workflows
4. End-to-end validation of the complete recording pipeline

---

## Technical Context

**Language/Version**: Swift 5.9 (Swift 6 compiler with 5.9 language mode)
**Primary Dependencies**: AVFoundation, ApplicationServices, Carbon, FluidAudio SDK
**Storage**: macOS Keychain (signing identity), File system (.signing-identity config)
**Testing**: XCTest (unit tests), XCUITest (E2E), smoke-test.sh (integration)
**Target Platform**: macOS 14+ (Sonoma and later)
**Project Type**: Single macOS native application (Swift Package Manager)
**Performance Goals**: Hotkey response < 50ms, permission checks < 100ms
**Constraints**: Non-sandboxed (required for Accessibility APIs), self-signed
  (no Apple Developer ID required)
**Scale/Scope**: Single developer to small team local development workflow

---

## Constitution Check

_GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design._

| Principle | Status | Notes |
|-----------|--------|-------|
| TypeScript-First | N/A | Swift project, not applicable |
| Specification-Driven | PASS | Feature spec exists with acceptance criteria |
| Security-First | PASS | Secrets in Keychain, .signing-identity gitignored |
| TDD Methodology | PARTIAL | Existing tests, new validation scripts |
| No secrets in code | PASS | Certificate in Keychain, config file excluded |
| Service Layer Architecture | PASS | Uses existing PermissionService |
| Explicit error handling | PASS | Custom error enums with LocalizedError |

**Gate Status**: PASS (no blocking violations)

**Note**: The constitution is web-focused (TypeScript/Node.js) but this is a
Swift/macOS project. Swift-specific best practices from AGENTS.md take
precedence:

- Use async/await for async operations
- Use actors for thread-safe concurrency
- Use @Observable for state management
- Use XCTest for testing

---

## Project Structure

### Documentation (this feature)

```text
specs/002-permission-signing/
├── plan.md              # This file (implementation plan)
├── spec.md              # Feature specification (input)
├── research.md          # Phase 0 output (completed)
├── data-model.md        # Phase 1 output (completed)
├── quickstart.md        # Phase 1 output (completed)
├── contracts/           # Phase 1 output (completed)
│   └── build-script-interface.md
├── checklists/          # Feature checklists
│   └── permissions.md   # Permission verification checklist
└── tasks.md             # Phase 2 output (created by /speckit.tasks)
```

### Source Code (repository root)

```text
scripts/
├── build-app.sh         # App bundle creation with signing [ENHANCE]
├── setup-signing.sh     # Certificate setup [ENHANCE]
└── smoke-test.sh        # Integration testing [EXISTS]

Sources/
├── Services/
│   ├── PermissionService.swift    # Permission checking [EXISTS]
│   └── AudioCaptureService.swift  # Audio capture [EXISTS]
└── Views/
    └── OnboardingViewModel.swift  # Permission onboarding [EXISTS]

docs/
├── LOCAL_DEVELOPMENT.md # New: Development setup guide [CREATE]
└── XCODE_WORKFLOW.md    # New: Xcode-specific guide [CREATE]

SpeechToText.entitlements # Entitlements file [EXISTS - no changes]
.signing-identity         # Signing config [GENERATED - gitignored]
```

**Structure Decision**: This feature primarily enhances build scripts and
documentation. No new Swift source files are required. The existing service
layer architecture (PermissionService, AudioCaptureService) already handles
permission checking correctly.

---

## Complexity Tracking

No constitution violations requiring justification. The feature is primarily
build tooling and documentation with minimal code changes.

---

## Phase 0: Research (Completed)

See [research.md](./research.md) for detailed findings.

### Key Decisions

| Topic | Decision | Rationale |
|-------|----------|-----------|
| Signing | Self-signed cert | No Apple Developer ID needed |
| Creation | OpenSSL + security CLI | Scriptable, existing impl |
| Validity | 10 years | Exceeds project lifespan |
| Xcode | Document alternative | Debugging advantages |
| Entitlements | No changes | Current file complete |

### Resolved Clarifications

1. TCC tracks identity via code signing + bundle ID
2. Self-signed certificates provide persistent identity
3. Entitlements file already covers all required permissions
4. Xcode manages its own signing (parallel workflow)
5. 10-year certificate validity minimizes renewal needs

---

## Phase 1: Design (Completed)

### Data Model

See [data-model.md](./data-model.md) for entity definitions.

**Key Entities**:

- `SigningIdentity`: Certificate in macOS Keychain
- `SigningConfiguration`: `.signing-identity` file referencing identity
- `Entitlements`: plist file declaring TCC capabilities
- `PermissionsGranted`: Runtime state (existing, no changes)

### Contracts

See [contracts/build-script-interface.md](./contracts/build-script-interface.md).

**Script Interfaces**:

- `setup-signing.sh`: Creates certificate, outputs `.signing-identity`
- `build-app.sh`: Builds and signs app, applies entitlements

### Quickstart Guide

See [quickstart.md](./quickstart.md) for developer onboarding.

---

## Phase 2: Implementation Tasks

_Note: Detailed tasks will be generated by `/speckit.tasks` command._

### Task Groups

#### P1: Persistent Code Signing Identity (Priority 1)

**Goal**: Ensure code signing identity persists across rebuilds.

**Tasks**:

1. Enhance `setup-signing.sh` with identity validation
2. Enhance `build-app.sh` with pre-build identity check
3. Add prominent warning for ad-hoc signing mode
4. Add `.signing-identity` to `.gitignore` if not present

**Acceptance Criteria**:

- Permissions persist across 10+ consecutive rebuilds
- Clear warning displayed when using ad-hoc signing

#### P2: Signing Setup Workflow (Priority 2)

**Goal**: Streamlined first-time setup experience.

**Tasks**:

1. Improve error messages in `setup-signing.sh`
2. Add Keychain Access fallback instructions
3. Validate identity exists before build starts
4. Create `docs/LOCAL_DEVELOPMENT.md`

**Acceptance Criteria**:

- New developers complete setup in < 5 minutes
- 90% of failures have actionable error messages

#### P3: Xcode Development Workflow (Priority 3)

**Goal**: Document Xcode as first-class alternative.

**Tasks**:

1. Create `docs/XCODE_WORKFLOW.md`
2. Document automatic signing behavior
3. Document debugger integration
4. Add troubleshooting section

**Acceptance Criteria**:

- Xcode workflow documented with step-by-step guide
- Permission persistence verified via Xcode builds

#### P4: End-to-End Recording Validation (Priority 4)

**Goal**: Verify complete recording pipeline works.

**Tasks**:

1. Enhance `smoke-test.sh` with permission verification
2. Add E2E test for record-transcribe-insert flow
3. Document manual validation steps

**Acceptance Criteria**:

- Complete workflow succeeds on first attempt after setup
- Smoke test validates all permission grants

---

## Implementation Approach

### What Exists (No Changes Needed)

The following components are already correctly implemented:

1. **SpeechToText.entitlements**: Complete with all required permissions
2. **PermissionService.swift**: Correct permission checking logic
3. **AudioCaptureService.swift**: Proper microphone access patterns
4. **setup-signing.sh**: Core certificate creation logic
5. **build-app.sh**: Core build and signing logic

### What Needs Enhancement

1. **setup-signing.sh Improvements**:
   - Add identity existence validation
   - Improve error messages with specific remediation steps
   - Add `--verify` flag to check existing identity

2. **build-app.sh Improvements**:
   - Validate identity exists in keychain before build
   - More prominent ad-hoc signing warning
   - Add `--check-signing` flag for pre-flight validation

3. **Documentation**:
   - Create `docs/LOCAL_DEVELOPMENT.md` (comprehensive setup guide)
   - Create `docs/XCODE_WORKFLOW.md` (Xcode-specific guide)
   - Update `README.md` with signing overview

### What Is NOT In Scope

The following are explicitly out of scope for this feature:

1. **Apple Developer ID signing**: Requires paid enrollment
2. **Notarization**: Only needed for distribution
3. **CI/CD signing**: Different identity management approach
4. **Sandbox enablement**: Would break accessibility APIs
5. **New Swift code for signing**: Build scripts handle this

---

## Risks and Mitigations

| Risk | Prob | Impact | Mitigation |
|------|------|--------|------------|
| Keychain prompts confuse users | Med | Low | Document in quickstart |
| Cert creation fails | Low | Med | Manual fallback instructions |
| Users skip setup, use ad-hoc | Med | Med | Prominent warning |
| Xcode/CLI conflicts | Low | Low | Document as separate workflows |

---

## Success Metrics

From spec requirements:

| Metric | Target | Measurement |
|--------|--------|-------------|
| Permission persistence | 10+ rebuilds | Manual test after each rebuild |
| Setup time | < 5 minutes | Time new developer setup |
| First-attempt success | 100% after setup | E2E test passes |
| Error message actionability | 90% | Review common failure scenarios |

---

## Dependencies

### Internal Dependencies

- Existing `scripts/build-app.sh`
- Existing `scripts/setup-signing.sh`
- Existing `SpeechToText.entitlements`

### External Dependencies

- macOS Keychain (system)
- OpenSSL (included with macOS)
- security CLI (included with macOS)
- codesign CLI (included with Xcode CLT)

### No New Package Dependencies

This feature does not add any new Swift packages or npm dependencies.

---

## Testing Strategy

### Unit Tests

No new unit tests required. Existing PermissionService tests remain valid.

### Integration Tests

1. **Script Tests** (manual verification):
   - `setup-signing.sh` creates valid certificate
   - `build-app.sh` signs with configured identity
   - Permissions persist across rebuilds

2. **Smoke Test** (automated):
   - Enhance `smoke-test.sh` to verify permission grants
   - Add signing verification step

### E2E Tests

1. **Permission Flow** (XCUITest):
   - Verify onboarding shows permission prompts
   - Verify app launches after permissions granted

2. **Recording Flow** (XCUITest):
   - Trigger hotkey
   - Verify recording modal appears
   - Verify transcription completes

---

## Generated Artifacts

| File | Description | Status |
|------|-------------|--------|
| `plan.md` | Implementation plan | Created |
| `research.md` | Research findings | Created |
| `data-model.md` | Entity definitions | Created |
| `quickstart.md` | Developer quickstart | Created |
| `contracts/build-script-interface.md` | Script contracts | Created |

---

## Next Steps

1. Run `/speckit.tasks` to generate detailed task breakdown
2. Create feature branch `002-permission-signing`
3. Implement P1 tasks (signing identity persistence)
4. Implement P2 tasks (setup workflow)
5. Implement P3 tasks (Xcode documentation)
6. Implement P4 tasks (E2E validation)
7. Create PR for review

---

## Appendix: File Locations

All generated artifacts are located at:

- Plan: `/workspace/specs/002-permission-signing/plan.md`
- Research: `/workspace/specs/002-permission-signing/research.md`
- Data Model: `/workspace/specs/002-permission-signing/data-model.md`
- Quickstart: `/workspace/specs/002-permission-signing/quickstart.md`
- Contracts: `/workspace/specs/002-permission-signing/contracts/build-script-interface.md`

Existing files that will be enhanced:

- Build script: `/workspace/scripts/build-app.sh`
- Setup script: `/workspace/scripts/setup-signing.sh`
- Entitlements: `/workspace/SpeechToText.entitlements`
