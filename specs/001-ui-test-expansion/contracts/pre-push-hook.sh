#!/bin/bash
# =============================================================================
# Contract: Pre-Push Hook with UI Test Integration
# Version: 1.0.0
# Date: 2026-01-03
# =============================================================================
#
# This contract defines the interface for the enhanced pre-push hook that
# integrates both unit tests and UI tests.
#
# USAGE:
#   git push                         # Runs both unit and UI tests
#   git push --no-verify             # Skips all hooks (not recommended)
#   SKIP_UI_TESTS=1 git push         # Skips UI tests, runs unit tests only
#   UI_TESTS_ONLY=1 git push         # Runs UI tests only, skips unit tests
#   UI_TEST_TIMEOUT=300 git push     # Sets 5 minute timeout for UI tests
#
# FLAGS (via environment variables):
#   SKIP_UI_TESTS    - Set to "1" to skip UI tests
#   UI_TESTS_ONLY    - Set to "1" to run only UI tests
#   UI_TEST_TIMEOUT  - Timeout in seconds (default: 600)
#   UI_TEST_VERBOSE  - Set to "1" for verbose output
#
# EXIT CODES:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Configuration or setup error
#
# =============================================================================

# Contract: Required functions and behavior

# parse_arguments()
# - Reads SKIP_UI_TESTS, UI_TESTS_ONLY, UI_TEST_TIMEOUT, UI_TEST_VERBOSE from environment
# - Validates mutually exclusive flags (SKIP_UI_TESTS and UI_TESTS_ONLY)
# - Returns configuration struct/variables

# run_unit_tests()
# - Calls scripts/remote-test.sh for unit test execution
# - Returns 0 on success, 1 on failure
# - Skipped if UI_TESTS_ONLY=1

# run_ui_tests()
# - Calls scripts/run-ui-tests.sh with appropriate flags
# - Applies UI_TEST_TIMEOUT as xcodebuild timeout
# - Returns 0 on success, 1 on failure
# - Skipped if SKIP_UI_TESTS=1

# report_results()
# - Prints summary of test results
# - Indicates which test suites passed/failed
# - Provides instructions on how to view detailed logs

# =============================================================================
# Contract: Expected Output Format
# =============================================================================
#
# SUCCESS:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Pre-Push Hook: Test Results
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [PASS] Unit Tests: 42 tests passed (12.3s)
# [PASS] UI Tests: 15 tests passed (45.2s)
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# All tests passed - push allowed
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# FAILURE:
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Pre-Push Hook: Test Results
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# [PASS] Unit Tests: 42 tests passed (12.3s)
# [FAIL] UI Tests: 2 of 15 tests failed (48.1s)
#        Failed: test_recording_modalAppears, test_settings_windowOpens
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# Tests failed - push blocked
# Fix the failing tests and try again.
# To bypass (not recommended): git push --no-verify
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
#
# =============================================================================

# Contract implementation placeholder
echo "This is a contract file - see scripts/pre-push for implementation"
exit 2
