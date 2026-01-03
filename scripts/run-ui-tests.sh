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
#   --grant-permissions   Pre-grant permissions via tccutil (requires sudo)
#   --reset              Reset app state before testing
#   --verbose            Show detailed output
#   --help               Show this help message
#
# Prerequisites:
#   - macOS 14+
#   - Xcode 15+
#   - SpeechToText.xcodeproj with UITests target
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUNDLE_ID="com.speechtotext.app"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_info() { echo -e "${BLUE}ℹ${NC} $1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }

GRANT_PERMISSIONS=false
RESET_STATE=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --grant-permissions) GRANT_PERMISSIONS=true; shift ;;
        --reset) RESET_STATE=true; shift ;;
        --verbose) VERBOSE=true; shift ;;
        --help) head -20 "$0" | tail -15; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

print_header "XCUITest Runner for SpeechToText"

# Pre-grant permissions if requested (requires sudo)
if [ "$GRANT_PERMISSIONS" = true ]; then
    print_info "Pre-granting permissions (requires sudo)..."

    # Reset and grant microphone access
    sudo tccutil reset Microphone "$BUNDLE_ID" 2>/dev/null || true
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

# Check for Xcode project
if [ ! -f "${PROJECT_ROOT}/SpeechToText.xcodeproj/project.pbxproj" ]; then
    print_warning "No Xcode project found. Creating one..."
    # For SPM projects, generate Xcode project
    cd "$PROJECT_ROOT"
    swift package generate-xcodeproj 2>/dev/null || true
fi

print_info "Running UI tests..."

# Run XCUITest
cd "$PROJECT_ROOT"

if [ "$VERBOSE" = true ]; then
    xcodebuild test \
        -scheme SpeechToText \
        -destination 'platform=macOS' \
        -testPlan UITests \
        2>&1 | xcpretty || xcodebuild test \
        -scheme SpeechToText \
        -destination 'platform=macOS' \
        2>&1
else
    xcodebuild test \
        -scheme SpeechToText \
        -destination 'platform=macOS' \
        -quiet \
        2>&1 || {
            print_error "UI tests failed"
            exit 1
        }
fi

print_success "UI tests completed"
