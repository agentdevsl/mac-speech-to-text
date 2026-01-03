#!/bin/bash
# =============================================================================
# debug-run.sh
# =============================================================================
# Run the app with debug logging enabled and Console.app monitoring
#
# Usage: ./scripts/debug-run.sh [options]
#
# Options:
#   --console     Open Console.app to monitor logs (default)
#   --no-console  Run without opening Console.app
#   --filter      Apply log filter (default: com.speechtotext)
#   --verbose     Show all log levels including debug
#   --release     Run release build instead of debug
#   --help        Show this help message
#
# =============================================================================

set -euo pipefail

# Configuration
APP_NAME="SpeechToText"
BUNDLE_ID="com.speechtotext.app"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUILD_DIR="${PROJECT_ROOT}/build"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Default options
OPEN_CONSOLE=true
LOG_FILTER="subsystem:${BUNDLE_ID}"
VERBOSE=false
BUILD_CONFIG="debug"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --console)
            OPEN_CONSOLE=true
            shift
            ;;
        --no-console)
            OPEN_CONSOLE=false
            shift
            ;;
        --filter)
            LOG_FILTER="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --release)
            BUILD_CONFIG="release"
            shift
            ;;
        --help|-h)
            head -25 "$0" | tail -20 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Debug Run: ${APP_NAME}${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check for macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}✗${NC} This script must be run on macOS"
    exit 1
fi

# Build the app
echo -e "${CYAN}ℹ${NC} Building ${BUILD_CONFIG} configuration..."
cd "${PROJECT_ROOT}"

if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release 2>&1 | tail -5
    APP_EXECUTABLE=".build/release/${APP_NAME}"
else
    swift build 2>&1 | tail -5
    APP_EXECUTABLE=".build/debug/${APP_NAME}"
fi

if [ ! -f "${APP_EXECUTABLE}" ]; then
    echo -e "${RED}✗${NC} Build failed"
    exit 1
fi
echo -e "${GREEN}✓${NC} Build complete"

# Open Console.app with filter
if [ "$OPEN_CONSOLE" = true ]; then
    echo -e "${CYAN}ℹ${NC} Opening Console.app with log filter..."

    # Create a log predicate for filtering
    if [ "$VERBOSE" = true ]; then
        PREDICATE="subsystem CONTAINS '${BUNDLE_ID}'"
    else
        PREDICATE="subsystem CONTAINS '${BUNDLE_ID}' AND messageType >= 1"
    fi

    # Open Console.app
    open -a Console

    # Give Console time to open
    sleep 1

    # Apply filter via AppleScript
    osascript <<EOF 2>/dev/null || true
tell application "Console"
    activate
end tell
EOF

    echo -e "${GREEN}✓${NC} Console.app opened"
    echo ""
    echo -e "${YELLOW}📋 In Console.app:${NC}"
    echo "   1. Click 'Start Streaming' if not already streaming"
    echo "   2. In search bar, enter: subsystem:${BUNDLE_ID}"
    echo "   3. Or use predicate: ${PREDICATE}"
    echo ""
fi

# Show log categories
echo -e "${CYAN}ℹ${NC} Log categories available:"
echo "   • app        - App lifecycle events"
echo "   • service    - Service layer operations"
echo "   • viewModel  - ViewModel operations"
echo "   • audio      - Audio capture/processing"
echo "   • system     - Permissions and system integration"
echo "   • analytics  - Statistics and usage tracking"
echo ""

# Enable debug logging via environment
export OS_ACTIVITY_MODE="debug"
export CFNETWORK_DIAGNOSTICS="3"

# Run the app
echo -e "${GREEN}▶${NC} Starting ${APP_NAME}..."
echo -e "${YELLOW}   Press Ctrl+C to stop${NC}"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Run with log streaming to terminal
"${APP_EXECUTABLE}" 2>&1 &
APP_PID=$!

# Stream logs to terminal
log stream --predicate "subsystem CONTAINS '${BUNDLE_ID}'" --style compact &
LOG_PID=$!

# Trap Ctrl+C to clean up
trap "kill ${APP_PID} ${LOG_PID} 2>/dev/null; echo ''; echo -e '${CYAN}ℹ${NC} App stopped'; exit 0" INT TERM

# Wait for app to exit
wait ${APP_PID} 2>/dev/null || true
kill ${LOG_PID} 2>/dev/null || true

echo ""
echo -e "${CYAN}ℹ${NC} ${APP_NAME} exited"
