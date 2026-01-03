#!/bin/bash
# =============================================================================
# open-xcode.sh
# =============================================================================
# Generate and open Xcode project for debugging with breakpoints
#
# Usage: ./scripts/open-xcode.sh
#
# This script:
# 1. Generates an Xcode project from Package.swift
# 2. Opens it in Xcode
# 3. Allows setting breakpoints and step-through debugging
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Terminal colors
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

echo -e "\n${CYAN}${BOLD}Opening SpeechToText in Xcode for Debugging${NC}\n"

cd "${PROJECT_ROOT}"

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${YELLOW}⚠️  Xcode not found. Install from App Store.${NC}"
    exit 1
fi

# Generate Xcode project
echo -e "${CYAN}ℹ${NC} Generating Xcode project from Package.swift..."
swift package generate-xcodeproj 2>/dev/null || {
    # If generate-xcodeproj fails (deprecated), use open directly
    echo -e "${CYAN}ℹ${NC} Opening Package.swift in Xcode..."
    open Package.swift
    exit 0
}

# Open in Xcode
if [ -d "SpeechToText.xcodeproj" ]; then
    echo -e "${GREEN}✓${NC} Opening SpeechToText.xcodeproj..."
    open SpeechToText.xcodeproj
else
    echo -e "${CYAN}ℹ${NC} Opening Package.swift in Xcode..."
    open Package.swift
fi

echo ""
echo -e "${GREEN}Debugging Tips:${NC}"
echo "  1. Select 'SpeechToText' scheme"
echo "  2. Set breakpoints by clicking in the gutter"
echo "  3. Press ⌘R to run with debugger attached"
echo "  4. Use Debug Navigator (⌘6) to view threads"
echo "  5. Use Console (⇧⌘C) to see log output"
echo ""
echo -e "${YELLOW}Recommended Breakpoints:${NC}"
echo "  • RecordingViewModel.startRecording()"
echo "  • RecordingViewModel.stopRecording()"
echo "  • AudioCaptureService.startCapture()"
echo "  • FluidAudioService.transcribe()"
echo "  • TextInsertionService.insertText()"
echo ""
