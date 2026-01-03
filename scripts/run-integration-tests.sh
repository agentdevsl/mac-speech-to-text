#!/bin/bash
# =============================================================================
# run-integration-tests.sh
# =============================================================================
# Run real-world integration tests (not mocks)
#
# Usage: ./scripts/run-integration-tests.sh [options]
#
# Options:
#   --filter NAME   Run only tests matching NAME
#   --verbose       Show verbose test output
#   --permissions   Run only permission check tests
#   --audio         Run only audio capture tests
#   --transcription Run only transcription tests
#   --all           Run all integration tests (default)
#   --help          Show this help message
#
# Prerequisites:
#   - Microphone permission granted
#   - Accessibility permission granted (for some tests)
#   - Input monitoring permission granted (for some tests)
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Default options
FILTER=""
VERBOSE=false
TEST_CATEGORY="all"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --permissions)
            TEST_CATEGORY="permissions"
            FILTER="Permission"
            shift
            ;;
        --audio)
            TEST_CATEGORY="audio"
            FILTER="AudioCapture"
            shift
            ;;
        --transcription)
            TEST_CATEGORY="transcription"
            FILTER="Transcription"
            shift
            ;;
        --all)
            TEST_CATEGORY="all"
            FILTER=""
            shift
            ;;
        --help|-h)
            head -30 "$0" | tail -25 | sed 's/^# //' | sed 's/^#//'
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${CYAN}  Integration Tests: SpeechToText${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Check for macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    echo -e "${RED}✗${NC} Integration tests must be run on macOS"
    exit 1
fi

cd "${PROJECT_ROOT}"

# Build test command
TEST_CMD="swift test --filter SpeechToTextIntegrationTests"

if [ -n "$FILTER" ]; then
    TEST_CMD="${TEST_CMD}/${FILTER}"
    echo -e "${CYAN}ℹ${NC} Running tests matching: ${FILTER}"
else
    echo -e "${CYAN}ℹ${NC} Running all integration tests"
fi

if [ "$VERBOSE" = true ]; then
    TEST_CMD="${TEST_CMD} -v"
fi

echo ""
echo -e "${YELLOW}⚠️  These tests use REAL services:${NC}"
echo "   • Real microphone input (speak when prompted)"
echo "   • Real FluidAudio transcription"
echo "   • Real permission checks"
echo ""
echo -e "${CYAN}Prerequisites:${NC}"
echo "   • Grant microphone permission to Terminal/IDE"
echo "   • Grant accessibility permission (optional)"
echo "   • Grant input monitoring permission (optional)"
echo ""

# Run tests
echo -e "${GREEN}▶${NC} Running integration tests..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Enable debug output for tests
export OS_ACTIVITY_MODE="debug"

eval "${TEST_CMD}" 2>&1

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}✓${NC} Integration tests complete"
