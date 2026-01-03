#!/bin/bash
# =============================================================================
# smoke-test.sh
# =============================================================================
# Runs the app briefly and checks for crashes and permission status
# Must be run on actual macOS hardware (not CI)
#
# Usage: ./scripts/smoke-test.sh [options]
#
# Options:
#   --build             Build the app before testing (default: use existing build)
#   --duration SECS     How long to run the app in seconds (default: 5)
#   --check-permissions Check permission and signing status only (no launch)
#   --help              Show this help message
#
# Exit Codes:
#   0 - No crashes detected / Permissions OK
#   1 - Crash detected
#   2 - Build failed
#   3 - App failed to launch
#   4 - Permission issues detected
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
APP_PATH="${PROJECT_ROOT}/build/SpeechToText.app"
CRASH_LOG_DIR="${HOME}/Library/Logs/DiagnosticReports"
BUNDLE_ID="com.speechtotext.app"
BUILD_FIRST=false
DURATION=5
CHECK_PERMISSIONS_ONLY=false

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

print_header() {
    echo -e "\n${BLUE}============================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}\n"
}

print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

show_help() {
    echo ""
    echo "Usage: ./scripts/smoke-test.sh [options]"
    echo ""
    echo "Runs the app briefly and checks for crashes and permission status."
    echo "Must be run on actual macOS hardware."
    echo ""
    echo "Options:"
    echo "  --build             Build the app before testing"
    echo "  --duration SECS     How long to run the app (default: 5 seconds)"
    echo "  --check-permissions Check permission status only (no app launch)"
    echo "  --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/smoke-test.sh --build            # Build and test"
    echo "  ./scripts/smoke-test.sh --duration 10      # Run for 10 seconds"
    echo "  ./scripts/smoke-test.sh --check-permissions # Check permissions only"
    echo ""
    echo "Exit Codes:"
    echo "  0 - Success (no crashes, permissions OK)"
    echo "  1 - Crash detected"
    echo "  2 - Build failed"
    echo "  3 - App failed to launch"
    echo "  4 - Permission issues detected"
    echo ""
    exit 0
}

# =============================================================================
# T033: Signing identity verification function
# =============================================================================
check_signing_identity() {
    local has_issues=false

    print_info "Checking code signing..."

    # Check if .signing-identity file exists
    local identity_file="${PROJECT_ROOT}/.signing-identity"
    if [ -f "$identity_file" ]; then
        local stored_identity
        stored_identity=$(cat "$identity_file" | tr -d '\n')
        print_success "Signing identity configured: ${stored_identity}"

        # Verify identity exists in keychain
        if security find-identity -v -p codesigning 2>/dev/null | grep -q "${stored_identity}"; then
            print_success "Identity found in keychain"
        else
            print_error "Identity NOT found in keychain!"
            has_issues=true
        fi
    else
        print_warning "No .signing-identity file - using ad-hoc signing"
        print_warning "Permissions will NOT persist across rebuilds"
        has_issues=true
    fi

    # Check app bundle signature if it exists
    if [ -d "$APP_PATH" ]; then
        local app_signature
        app_signature=$(codesign -dv "$APP_PATH" 2>&1 | grep "Authority=" | head -1 || echo "")

        if [ -n "$app_signature" ]; then
            print_success "App is signed: ${app_signature}"
        else
            # Check if ad-hoc signed
            local adhoc_check
            adhoc_check=$(codesign -dv "$APP_PATH" 2>&1 | grep "Signature=adhoc" || echo "")
            if [ -n "$adhoc_check" ]; then
                print_warning "App is ad-hoc signed (permissions won't persist)"
            else
                print_warning "App signature status unclear"
            fi
        fi
    fi

    if [ "$has_issues" = true ]; then
        return 1
    fi
    return 0
}

# =============================================================================
# T031: Microphone permission check function
# =============================================================================
check_microphone_permission() {
    print_info "Checking microphone permission..."

    # Check TCC database for microphone permission
    # Note: Direct TCC database access may require Full Disk Access
    # We use sqlite3 if available, otherwise provide guidance

    local tcc_db="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"

    if [ -f "$tcc_db" ]; then
        # Try to query TCC database
        local mic_status
        mic_status=$(sqlite3 "$tcc_db" "SELECT auth_value FROM access WHERE service='kTCCServiceMicrophone' AND client='${BUNDLE_ID}'" 2>/dev/null || echo "unknown")

        case "$mic_status" in
            "2")
                print_success "Microphone permission: GRANTED"
                return 0
                ;;
            "0")
                print_error "Microphone permission: DENIED"
                echo ""
                echo "  Remediation:"
                echo "    1. Open System Settings > Privacy & Security > Microphone"
                echo "    2. Find 'SpeechToText' and toggle ON"
                echo ""
                return 1
                ;;
            "unknown"|"")
                print_warning "Microphone permission: NOT YET REQUESTED"
                echo ""
                echo "  The app hasn't requested microphone access yet."
                echo "  Run the app and grant permission when prompted."
                echo ""
                return 1
                ;;
            *)
                print_warning "Microphone permission: UNKNOWN STATUS (${mic_status})"
                return 1
                ;;
        esac
    else
        print_warning "Cannot read TCC database (may need Full Disk Access)"
        echo ""
        echo "  To check manually:"
        echo "    1. Open System Settings > Privacy & Security > Microphone"
        echo "    2. Look for 'SpeechToText' in the list"
        echo ""
        return 1
    fi
}

# =============================================================================
# T032: Accessibility permission check function
# =============================================================================
check_accessibility_permission() {
    print_info "Checking accessibility permission..."

    local tcc_db="${HOME}/Library/Application Support/com.apple.TCC/TCC.db"

    if [ -f "$tcc_db" ]; then
        # Try to query TCC database for accessibility
        local acc_status
        acc_status=$(sqlite3 "$tcc_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='${BUNDLE_ID}'" 2>/dev/null || echo "unknown")

        case "$acc_status" in
            "2")
                print_success "Accessibility permission: GRANTED"
                return 0
                ;;
            "0")
                print_error "Accessibility permission: DENIED"
                echo ""
                echo "  Remediation:"
                echo "    1. Open System Settings > Privacy & Security > Accessibility"
                echo "    2. Find 'SpeechToText' and toggle ON"
                echo ""
                return 1
                ;;
            "unknown"|"")
                print_warning "Accessibility permission: NOT YET REQUESTED"
                echo ""
                echo "  The app hasn't been added to Accessibility list yet."
                echo "  Run the app and add it in System Settings when prompted."
                echo ""
                return 1
                ;;
            *)
                print_warning "Accessibility permission: UNKNOWN STATUS (${acc_status})"
                return 1
                ;;
        esac
    else
        # Fallback: Check using AXIsProcessTrusted via osascript
        print_warning "Cannot read TCC database directly"
        echo ""
        echo "  To check manually:"
        echo "    1. Open System Settings > Privacy & Security > Accessibility"
        echo "    2. Look for 'SpeechToText' in the list"
        echo ""
        return 1
    fi
}

# =============================================================================
# T030 & T034: --check-permissions flag and status reporting
# =============================================================================
check_all_permissions() {
    print_header "Permission and Signing Status Check"

    local overall_status=0

    # Check signing
    echo ""
    if ! check_signing_identity; then
        overall_status=1
    fi

    # Check microphone
    echo ""
    if ! check_microphone_permission; then
        overall_status=1
    fi

    # Check accessibility
    echo ""
    if ! check_accessibility_permission; then
        overall_status=1
    fi

    # Summary
    print_header "Status Summary"

    echo ""
    echo "Permission Status Report"
    echo "========================"
    echo ""

    # Signing status
    if [ -f "${PROJECT_ROOT}/.signing-identity" ]; then
        local identity
        identity=$(cat "${PROJECT_ROOT}/.signing-identity" | tr -d '\n')
        if security find-identity -v -p codesigning 2>/dev/null | grep -q "${identity}"; then
            echo "  Signing Identity:  [OK] ${identity}"
        else
            echo "  Signing Identity:  [MISSING] ${identity}"
            overall_status=1
        fi
    else
        echo "  Signing Identity:  [AD-HOC] Permissions won't persist"
        overall_status=1
    fi

    # App bundle status
    if [ -d "$APP_PATH" ]; then
        echo "  App Bundle:        [OK] ${APP_PATH}"
    else
        echo "  App Bundle:        [MISSING] Run ./scripts/build-app.sh"
        overall_status=1
    fi

    # Entitlements status
    if [ -f "${PROJECT_ROOT}/SpeechToText.entitlements" ]; then
        echo "  Entitlements:      [OK] SpeechToText.entitlements"
    else
        echo "  Entitlements:      [MISSING]"
        overall_status=1
    fi

    echo ""

    if [ "$overall_status" -eq 0 ]; then
        print_success "All checks passed!"
        echo ""
        echo "The app should be ready for testing."
        echo "Run: open ${APP_PATH}"
        echo ""
    else
        print_warning "Some issues detected - see above for remediation steps"
        echo ""
        echo "Quick fixes:"
        echo "  1. Set up signing:  ./scripts/setup-signing.sh"
        echo "  2. Build app:       ./scripts/build-app.sh"
        echo "  3. Grant permissions in System Settings"
        echo ""
        return 4
    fi

    return 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD_FIRST=true
            shift
            ;;
        --duration)
            if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ ]]; then
                print_error "--duration requires a positive integer (seconds)"
                exit 1
            fi
            DURATION="$2"
            shift 2
            ;;
        --check-permissions)
            CHECK_PERMISSIONS_ONLY=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Handle --check-permissions flag
if [ "$CHECK_PERMISSIONS_ONLY" = true ]; then
    check_all_permissions
    exit $?
fi

# Standard smoke test
print_header "Smoke Test for SpeechToText"

# Check macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

# Show signing status before build
echo ""
check_signing_identity || true
echo ""

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
open "$APP_PATH"

# Verify app actually started
LAUNCH_ATTEMPTS=0
while ! pgrep -f "${APP_PATH}/Contents/MacOS/SpeechToText" >/dev/null 2>&1; do
    sleep 0.5
    LAUNCH_ATTEMPTS=$((LAUNCH_ATTEMPTS + 1))
    if [ "$LAUNCH_ATTEMPTS" -ge 10 ]; then
        print_error "App failed to launch within 5 seconds"
        print_info "Check Console.app for launch errors"
        exit 3
    fi
done
print_success "App launched successfully"

# Wait for test duration
sleep "$DURATION"

# Kill app gracefully using osascript (safer than pkill pattern matching)
print_info "Stopping app..."
osascript -e 'quit app "SpeechToText"' 2>/dev/null || true
sleep 1
# Fallback: kill by bundle ID if app didn't quit cleanly
pkill -f "${APP_PATH}/Contents/MacOS/SpeechToText" 2>/dev/null || true

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
    echo ""

    # Show permission status after successful run
    print_info "Checking permission status..."
    echo ""
    check_all_permissions || true

    exit 0
fi
