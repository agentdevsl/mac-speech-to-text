# Tasks: Permission and Code Signing for Local Development

**Input**: Design documents from `/workspace/specs/002-permission-signing/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md
**Issue**: #10

**Tests**: Tests NOT explicitly requested. Focus on build scripts and docs.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story (US1, US2, US3, US4)
- All file paths are absolute from repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and verification

- [ ] T001 Verify scripts are executable in `/workspace/scripts/`
- [ ] T002 [P] Verify entitlements has required permissions
- [ ] T003 [P] Verify .signing-identity is in .gitignore

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story

**CRITICAL**: No user story work can begin until this phase is complete

- [ ] T004 Create backup of `/workspace/scripts/setup-signing.sh`
- [ ] T005 [P] Create backup of `/workspace/scripts/build-app.sh`
- [ ] T006 [P] Create `/workspace/docs/` directory if needed

**Checkpoint**: Foundation ready - user story work can now begin

---

## Phase 3: User Story 1 - Persistent Code Signing Identity (P1)

**Goal**: Ensure signing identity persists across rebuilds

**Independent Test**: Build twice, grant permissions after first build,
verify permissions remain granted after second build without re-auth

**Acceptance Criteria**:

- Permissions persist across 10+ consecutive rebuilds
- Clear warning displayed when using ad-hoc signing

### Implementation for User Story 1

- [ ] T007 [US1] Add --verify flag to check existing identity
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T008 [US1] Add identity validation function to verify cert in keychain
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T009 [US1] Add expiration check for existing certificates
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T010 [US1] Enhance error output with remediation steps
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T011 [US1] Add pre-build identity validation function
  - File: `/workspace/scripts/build-app.sh`
- [ ] T012 [US1] Add --check-signing flag for pre-flight validation
  - File: `/workspace/scripts/build-app.sh`
- [ ] T013 [US1] Make ad-hoc signing warning more prominent
  - File: `/workspace/scripts/build-app.sh`
- [ ] T014 [US1] Add recommendation to run setup-signing.sh on ad-hoc
  - File: `/workspace/scripts/build-app.sh`
- [ ] T015 [US1] Verify .signing-identity entry in .gitignore

**Checkpoint**: US1 functional - signing identity persists across rebuilds

---

## Phase 4: User Story 2 - Signing Setup Workflow (P2)

**Goal**: Streamlined first-time setup (< 5 minutes)

**Independent Test**: Run setup script on fresh clone, verify subsequent
builds maintain permission persistence

**Acceptance Criteria**:

- New developers complete setup in less than 5 minutes
- 90% of failures have actionable error messages

### Implementation for User Story 2

- [ ] T016 [US2] Add prerequisite check (security, codesign, openssl)
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T017 [US2] Add Keychain Access GUI fallback instructions
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T018 [US2] Add --force flag to recreate certificate
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T019 [US2] Add certificate CN validation (1-64 chars)
  - File: `/workspace/scripts/setup-signing.sh`
- [ ] T020 [P] [US2] Create comprehensive LOCAL_DEVELOPMENT.md
  - File: `/workspace/docs/LOCAL_DEVELOPMENT.md`
- [ ] T021 [US2] Add quickstart reference section
  - File: `/workspace/docs/LOCAL_DEVELOPMENT.md`
- [ ] T022 [US2] Add troubleshooting section
  - File: `/workspace/docs/LOCAL_DEVELOPMENT.md`
- [ ] T023 [US2] Add TCC and code signing relationship explanation
  - File: `/workspace/docs/LOCAL_DEVELOPMENT.md`

**Checkpoint**: US1 AND US2 work - first-time setup is streamlined

---

## Phase 5: User Story 3 - Xcode Development Workflow (P3)

**Goal**: Document Xcode as first-class alternative workflow

**Independent Test**: Open in Xcode, build, verify permissions persist

**Acceptance Criteria**:

- Xcode workflow documented with step-by-step guide
- Permission persistence verified via Xcode builds

### Implementation for User Story 3

- [ ] T024 [P] [US3] Create XCODE_WORKFLOW.md
  - File: `/workspace/docs/XCODE_WORKFLOW.md`
- [ ] T025 [US3] Document automatic signing behavior
  - File: `/workspace/docs/XCODE_WORKFLOW.md`
- [ ] T026 [US3] Document debugger integration (LLDB, breakpoints)
  - File: `/workspace/docs/XCODE_WORKFLOW.md`
- [ ] T027 [US3] Add troubleshooting section for Xcode signing
  - File: `/workspace/docs/XCODE_WORKFLOW.md`
- [ ] T028 [US3] Document when to use Xcode vs CLI workflow
  - File: `/workspace/docs/XCODE_WORKFLOW.md`
- [ ] T029 [US3] Add permission persistence verification section
  - File: `/workspace/docs/XCODE_WORKFLOW.md`

**Checkpoint**: US1, US2, US3 work - CLI and Xcode workflows documented

---

## Phase 6: User Story 4 - End-to-End Recording Validation (P4)

**Goal**: Verify complete recording pipeline works

**Independent Test**: Record speech, observe transcription, verify text
insertion into target application

**Acceptance Criteria**:

- Complete workflow succeeds on first attempt after setup
- Smoke test validates all permission grants

### Implementation for User Story 4

- [ ] T030 [US4] Add --check-permissions flag
  - File: `/workspace/scripts/smoke-test.sh`
- [ ] T031 [US4] Add microphone permission check function
  - File: `/workspace/scripts/smoke-test.sh`
- [ ] T032 [US4] Add accessibility permission check function
  - File: `/workspace/scripts/smoke-test.sh`
- [ ] T033 [US4] Add signing identity verification
  - File: `/workspace/scripts/smoke-test.sh`
- [ ] T034 [US4] Add permission status reporting output
  - File: `/workspace/scripts/smoke-test.sh`
- [ ] T035 [P] [US4] Create manual validation checklist
  - File: `/workspace/specs/002-permission-signing/checklists/validation.md`
- [ ] T036 [US4] Document E2E test steps in validation checklist

**Checkpoint**: All user stories complete - full workflow validated

---

## Phase 7: Polish and Cross-Cutting Concerns

**Purpose**: Improvements affecting multiple user stories

- [ ] T037 [P] Add signing setup recommendation to README.md
- [ ] T038 [P] Update quickstart.md with discovered improvements
- [ ] T039 Verify all new documentation has consistent formatting
- [ ] T040 Run quickstart.md validation manually
- [ ] T041 Update plan.md to mark Phase 2 as complete

---

## Dependencies and Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies
- **Foundational (Phase 2)**: Depends on Setup - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational
- **User Story 2 (Phase 4)**: Depends on US1 completion
- **User Story 3 (Phase 5)**: Can start after Foundational (independent)
- **User Story 4 (Phase 6)**: Depends on US1 completion
- **Polish (Phase 7)**: Depends on all user stories

### Parallel Opportunities

**Phase 2 (Foundational)**:

- T004, T005, T006 can run in parallel

**Phase 3 (US1)**:

- T007-T010 (setup-signing.sh) must be sequential
- T011-T014 (build-app.sh) can run in parallel with T007-T010
- T015 (gitignore) can run in parallel with all

**Phase 5 (US3)**:

- Entire phase can run in parallel with Phase 3/4

---

## File Modification Summary

| File | Tasks | Story |
|------|-------|-------|
| `scripts/setup-signing.sh` | T007-T010, T016-T019 | US1, US2 |
| `scripts/build-app.sh` | T011-T014 | US1 |
| `scripts/smoke-test.sh` | T030-T034 | US4 |
| `.gitignore` | T003, T015 | US1 |
| `docs/LOCAL_DEVELOPMENT.md` | T020-T023 | US2 |
| `docs/XCODE_WORKFLOW.md` | T024-T029 | US3 |
| `specs/.../checklists/validation.md` | T035-T036 | US4 |
| `README.md` | T037 | Polish |

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- Each user story independently completable and testable
- Commit after each task or logical group
- No new Swift code required - build scripts and documentation only
