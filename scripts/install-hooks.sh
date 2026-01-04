#!/bin/bash
# =============================================================================
# Install Git Hooks
# =============================================================================
# Installs pre-push hook for running tests before push
#
# Usage: ./scripts/install-hooks.sh
#
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
GIT_HOOKS_DIR="${PROJECT_ROOT}/.git/hooks"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}Installing Git hooks...${NC}"

# Check if .git directory exists
if [ ! -d "${PROJECT_ROOT}/.git" ]; then
    echo "Error: Not a git repository"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "${GIT_HOOKS_DIR}"

# Install pre-push hook
if [ -f "${SCRIPT_DIR}/pre-push" ]; then
    cp "${SCRIPT_DIR}/pre-push" "${GIT_HOOKS_DIR}/pre-push"
    chmod +x "${GIT_HOOKS_DIR}/pre-push"
    echo -e "${GREEN}[OK]${NC} Installed pre-push hook"
else
    echo "Warning: pre-push script not found at ${SCRIPT_DIR}/pre-push"
fi

echo ""
echo "Git hooks installed successfully!"
echo ""
echo "Usage:"
echo "  git push                     # Runs unit + UI tests on macdev"
echo "  SKIP_UI_TESTS=1 git push     # Skip UI tests"
echo "  UI_TESTS_ONLY=1 git push     # Only UI tests"
echo "  git push --no-verify         # Skip all hooks (not recommended)"
echo ""
echo "To configure SSH for macdev:"
echo "  ./scripts/setup-ssh-for-mac.sh"
