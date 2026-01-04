#!/bin/bash
# =============================================================================
# run-ui-tests.sh
# =============================================================================
# Runs XCUITest UI tests for end-to-end testing
# Must be run on actual macOS hardware
#
# Usage: ./scripts/run-ui-tests.sh [options]
#
# Options:
#   --test-plan <plan>    Run specific test plan (AllUITests, P1OnlyTests, AccessibilityTests)
#   --grant-permissions   Pre-grant permissions via tccutil (requires sudo)
#   --reset               Reset app state before testing
#   --verbose             Show detailed xcodebuild output
#   --timeout <seconds>   Test timeout (default: 600 = 10 minutes)
#   --help                Show this help message
#
# Environment Variables:
#   UI_TEST_TIMEOUT       Timeout in seconds (default: 600)
#   UI_TEST_VERBOSE       Set to "1" for verbose output
#
# Prerequisites:
#   - macOS 14+
#   - Xcode 15+
#   - SpeechToText scheme with UITests target
#
# Exit Codes:
#   0 - All tests passed
#   1 - One or more tests failed
#   2 - Configuration or setup error
#   124 - Timeout exceeded
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUNDLE_ID="com.example.SpeechToText"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# Default values
GRANT_PERMISSIONS=false
RESET_STATE=false
VERBOSE="${UI_TEST_VERBOSE:-false}"
TEST_PLAN=""
TIMEOUT="${UI_TEST_TIMEOUT:-600}"
START_TIME=$(date +%s)

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-plan)
            TEST_PLAN="$2"
            shift 2
            ;;
        --test-plan=*)
            TEST_PLAN="${1#*=}"
            shift
            ;;
        --grant-permissions)
            GRANT_PERMISSIONS=true
            shift
            ;;
        --reset)
            RESET_STATE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --timeout=*)
            TIMEOUT="${1#*=}"
            shift
            ;;
        --help|-h)
            head -30 "$0" | tail -26
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 2
            ;;
    esac
done

print_header "XCUITest Runner for SpeechToText"

echo -e "${CYAN}Configuration:${NC}"
echo "  Test Plan:   ${TEST_PLAN:-All}"
echo "  Timeout:     ${TIMEOUT}s"
echo "  Verbose:     ${VERBOSE}"
echo "  Reset State: ${RESET_STATE}"
echo ""

# Pre-grant permissions if requested (requires sudo)
if [ "$GRANT_PERMISSIONS" = true ]; then
    print_info "Pre-granting permissions (requires sudo)..."

    # Reset and grant microphone access
    sudo tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true
    sudo tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
    # Note: tccutil can reset but not grant - actual grant requires user interaction
    # For automated testing, use MDM profiles or test on pre-configured machines

    print_warning "Note: Full permission grant requires MDM or manual approval"
fi

# Reset app state if requested
if [ "$RESET_STATE" = true ]; then
    print_info "Resetting app state..."
    defaults delete "$BUNDLE_ID" 2>/dev/null || true
    rm -rf ~/Library/Application\ Support/SpeechToText 2>/dev/null || true
    print_success "App state reset"
fi

# Check for Xcode
if ! command -v xcodebuild &>/dev/null; then
    print_error "xcodebuild not found. Please install Xcode Command Line Tools."
    exit 2
fi

# Resolve Swift packages
print_info "Resolving Swift packages..."
cd "$PROJECT_ROOT"
swift package resolve 2>/dev/null || true

# Build xcodebuild command
XCODEBUILD_CMD=(
    xcodebuild test
    -scheme SpeechToText
    -destination 'platform=macOS'
)

# Add test plan if specified
if [ -n "$TEST_PLAN" ]; then
    # Check if test plan file exists
    TEST_PLAN_FILE="${PROJECT_ROOT}/UITests/TestPlans/${TEST_PLAN}.xctestplan"
    if [ -f "$TEST_PLAN_FILE" ]; then
        XCODEBUILD_CMD+=(-testPlan "$TEST_PLAN")
        print_info "Using test plan: $TEST_PLAN"
    else
        print_warning "Test plan file not found: $TEST_PLAN_FILE"
        print_info "Running all tests instead"
    fi
fi

# Add quiet flag if not verbose
if [ "$VERBOSE" != "true" ]; then
    XCODEBUILD_CMD+=(-quiet)
fi

print_info "Running UI tests..."
print_info "Command: ${XCODEBUILD_CMD[*]}"
echo ""

# Run tests with timeout
TEST_EXIT_CODE=0
set +e

if command -v timeout &>/dev/null; then
    timeout "${TIMEOUT}" "${XCODEBUILD_CMD[@]}" 2>&1
    TEST_EXIT_CODE=$?
elif command -v gtimeout &>/dev/null; then
    # macOS with coreutils installed via homebrew
    gtimeout "${TIMEOUT}" "${XCODEBUILD_CMD[@]}" 2>&1
    TEST_EXIT_CODE=$?
else
    # Fallback: run without timeout
    print_warning "timeout command not found, running without timeout limit"
    "${XCODEBUILD_CMD[@]}" 2>&1
    TEST_EXIT_CODE=$?
fi

set -e

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
print_header "Test Results"

# Handle exit codes
if [ $TEST_EXIT_CODE -eq 0 ]; then
    print_success "All UI tests passed (${DURATION}s)"
    exit 0
elif [ $TEST_EXIT_CODE -eq 124 ]; then
    print_error "UI tests timed out after ${TIMEOUT}s"
    exit 124
else
    print_error "UI tests failed with exit code ${TEST_EXIT_CODE} (${DURATION}s)"

    # Provide helpful information
    echo ""
    echo "Troubleshooting:"
    echo "  1. Run with --verbose for detailed output"
    echo "  2. Check test-screenshots/ for failure screenshots"
    echo "  3. Open xcresult bundle in Xcode for detailed logs"
    echo ""
    echo "To run only P1 tests (faster):"
    echo "  ./scripts/run-ui-tests.sh --test-plan P1OnlyTests"
    echo ""

    exit 1
fi
