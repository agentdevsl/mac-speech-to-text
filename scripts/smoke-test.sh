#!/bin/bash
# =============================================================================
# smoke-test.sh
# =============================================================================
# Runs the app briefly and checks for crashes
# Must be run on actual macOS hardware (not CI)
#
# Usage: ./scripts/smoke-test.sh [options]
#
# Options:
#   --build     Build the app before testing (default: use existing build)
#   --duration  How long to run the app in seconds (default: 5)
#   --help      Show this help message
#
# Exit Codes:
#   0 - No crashes detected
#   1 - Crash detected
#   2 - Build failed
#   3 - App failed to launch
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
APP_PATH="${PROJECT_ROOT}/build/SpeechToText.app"
CRASH_LOG_DIR="${HOME}/Library/Logs/DiagnosticReports"
BUILD_FIRST=false
DURATION=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}${1}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_info() { echo -e "${BLUE}ℹ${NC} $1"; }

show_help() {
    head -20 "$0" | tail -15
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build) BUILD_FIRST=true; shift ;;
        --duration) DURATION="$2"; shift 2 ;;
        --help) show_help ;;
        *) echo "Unknown option: $1"; show_help ;;
    esac
done

print_header "Smoke Test for SpeechToText"

# Get initial crash count
INITIAL_CRASH_COUNT=$(ls "${CRASH_LOG_DIR}"/SpeechToText*.ips 2>/dev/null | wc -l | tr -d ' ' || echo "0")
print_info "Initial crash reports: ${INITIAL_CRASH_COUNT}"

# Build if requested
if [ "$BUILD_FIRST" = true ]; then
    print_info "Building app..."
    if ! "${SCRIPT_DIR}/build-app.sh" --release; then
        print_error "Build failed"
        exit 2
    fi
fi

# Check app exists
if [ ! -d "$APP_PATH" ]; then
    print_error "App not found at ${APP_PATH}"
    print_info "Run with --build to build first"
    exit 3
fi

# Launch app
print_info "Launching app for ${DURATION} seconds..."
open "$APP_PATH" &

# Wait
sleep "$DURATION"

# Kill app gracefully
print_info "Stopping app..."
pkill -f "SpeechToText" 2>/dev/null || true
sleep 1

# Check for new crashes
FINAL_CRASH_COUNT=$(ls "${CRASH_LOG_DIR}"/SpeechToText*.ips 2>/dev/null | wc -l | tr -d ' ' || echo "0")
NEW_CRASHES=$((FINAL_CRASH_COUNT - INITIAL_CRASH_COUNT))

print_header "Results"

if [ "$NEW_CRASHES" -gt 0 ]; then
    print_error "FAILED: ${NEW_CRASHES} new crash(es) detected!"
    echo ""
    print_info "Recent crash logs:"
    ls -lt "${CRASH_LOG_DIR}"/SpeechToText*.ips 2>/dev/null | head -5

    echo ""
    print_info "Crash summary:"
    # Show exception type from most recent crash
    LATEST_CRASH=$(ls -t "${CRASH_LOG_DIR}"/SpeechToText*.ips 2>/dev/null | head -1)
    if [ -n "$LATEST_CRASH" ]; then
        grep -A2 '"exception"' "$LATEST_CRASH" 2>/dev/null | head -5 || true
    fi

    exit 1
else
    print_success "PASSED: No crashes detected"
    exit 0
fi
