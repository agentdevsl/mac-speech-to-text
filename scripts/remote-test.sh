#!/bin/bash
# =============================================================================
# Remote Test Runner for macOS Swift Project
# =============================================================================
# Syncs local changes to remote Mac and runs swift test
# Designed for pre-push hook integration
#
# Usage: ./scripts/remote-test.sh [options]
#
# Options:
#   --dry-run     Show what would be synced without actually syncing
#   --no-sync     Skip sync, only run tests (assumes code is already synced)
#   --sync-mode   Sync method: rsync (default), git, or scp
#   --verbose     Show detailed output
#   --help        Show this help message
#
# Exit Codes:
#   0 - All tests passed
#   1 - Tests failed
#   2 - Sync failed
#   3 - SSH connection failed
#   4 - Configuration error
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
SSH_HOST="${REMOTE_TEST_HOST:-macdev}"
REMOTE_PROJECT_PATH="${REMOTE_TEST_PATH:-~/Developer/mac-speech-to-text}"
LOCAL_PROJECT_PATH="${LOCAL_PROJECT_PATH:-$(pwd)}"
TEST_TIMEOUT="${TEST_TIMEOUT:-600}"  # 10 minutes default
SYNC_MODE="${SYNC_MODE:-auto}"       # auto, rsync, git, or scp

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}$1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    head -25 "$0" | tail -20
    exit 0
}

# Check SSH connection
check_ssh() {
    print_status "Checking SSH connection to ${SSH_HOST}..."

    if ! ssh -o ConnectTimeout=5 -o BatchMode=yes "${SSH_HOST}" "echo 'connected'" &>/dev/null; then
        print_error "Cannot connect to ${SSH_HOST}"
        print_error "Please check:"
        echo "  1. SSH key is configured: ssh-add -l"
        echo "  2. Host is reachable: ping ${SSH_HOST}"
        echo "  3. SSH config exists: cat ~/.ssh/config"
        return 3
    fi

    print_success "SSH connection verified"
    return 0
}

# Detect best sync method
detect_sync_method() {
    if [[ "${SYNC_MODE}" != "auto" ]]; then
        echo "${SYNC_MODE}"
        return
    fi

    # Check if rsync is available locally
    if command -v rsync &>/dev/null; then
        echo "rsync"
        return
    fi

    # Check if we're in a git repo and remote has git
    if git rev-parse --git-dir &>/dev/null; then
        echo "git"
        return
    fi

    # Fallback to scp
    echo "scp"
}

# Sync code using rsync
sync_rsync() {
    local dry_run_flag=""
    [[ "${DRY_RUN:-false}" == "true" ]] && dry_run_flag="--dry-run"

    # Build rsync exclude list
    local excludes=(
        ".git"
        ".build"
        "*.xcodeproj"
        "*.xcworkspace"
        "DerivedData"
        ".DS_Store"
        "*.swp"
        "*.swo"
        ".env"
        ".env.*"
        "node_modules"
        "__pycache__"
    )

    local exclude_args=""
    for pattern in "${excludes[@]}"; do
        exclude_args="${exclude_args} --exclude=${pattern}"
    done

    local rsync_cmd="rsync -avz --progress --delete ${dry_run_flag} ${exclude_args} ${LOCAL_PROJECT_PATH}/ ${SSH_HOST}:${REMOTE_PROJECT_PATH}/"

    if [[ "${VERBOSE:-false}" == "true" ]]; then
        print_status "Rsync command: ${rsync_cmd}"
    fi

    eval "${rsync_cmd}"
}

# Sync code using git (commit locally, pull on remote)
sync_git() {
    local current_branch
    current_branch=$(git rev-parse --abbrev-ref HEAD)

    print_status "Syncing via git (branch: ${current_branch})..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_status "[DRY RUN] Would commit local changes and pull on remote"
        git status --short
        return 0
    fi

    # Check for uncommitted changes
    if ! git diff --quiet HEAD 2>/dev/null; then
        print_status "Stashing local changes for sync..."
        git stash push -m "remote-test-sync-$(date +%s)"
        STASH_CREATED=true
    fi

    # Push current branch
    print_status "Pushing to origin/${current_branch}..."
    if ! git push origin "${current_branch}" 2>&1; then
        print_warning "Push failed, trying with --force-with-lease..."
        git push --force-with-lease origin "${current_branch}" 2>&1 || true
    fi

    # Pull on remote
    print_status "Pulling on remote..."
    ssh "${SSH_HOST}" "cd ${REMOTE_PROJECT_PATH} && git fetch origin && git checkout ${current_branch} && git reset --hard origin/${current_branch}"

    # Restore stash if created
    if [[ "${STASH_CREATED:-false}" == "true" ]]; then
        print_status "Restoring stashed changes..."
        git stash pop || true
    fi

    return 0
}

# Sync code using scp (fallback)
sync_scp() {
    print_status "Syncing via scp (may be slow for large projects)..."

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        print_status "[DRY RUN] Would copy Sources/ and Tests/ to remote"
        return 0
    fi

    # Create temp archive excluding build artifacts
    local tmp_archive="/tmp/remote-test-sync-$$.tar.gz"
    tar --exclude='.git' \
        --exclude='.build' \
        --exclude='DerivedData' \
        --exclude='*.xcodeproj' \
        --exclude='*.xcworkspace' \
        --exclude='.DS_Store' \
        -czf "${tmp_archive}" \
        -C "${LOCAL_PROJECT_PATH}" \
        Sources Tests Package.swift 2>/dev/null || true

    # Copy and extract on remote
    scp "${tmp_archive}" "${SSH_HOST}:/tmp/"
    ssh "${SSH_HOST}" "cd ${REMOTE_PROJECT_PATH} && tar -xzf /tmp/$(basename ${tmp_archive})"

    # Cleanup
    rm -f "${tmp_archive}"
    ssh "${SSH_HOST}" "rm -f /tmp/$(basename ${tmp_archive})"

    return 0
}

# Sync code to remote
sync_code() {
    local method
    method=$(detect_sync_method)

    print_status "Syncing code to ${SSH_HOST}:${REMOTE_PROJECT_PATH} (method: ${method})..."

    case "${method}" in
        rsync)
            if ! sync_rsync; then
                print_error "Failed to sync code via rsync"
                return 2
            fi
            ;;
        git)
            if ! sync_git; then
                print_error "Failed to sync code via git"
                return 2
            fi
            ;;
        scp)
            if ! sync_scp; then
                print_error "Failed to sync code via scp"
                return 2
            fi
            ;;
        *)
            print_error "Unknown sync method: ${method}"
            return 4
            ;;
    esac

    print_success "Code synced successfully"
    return 0
}

# Resolve Swift packages on remote
resolve_packages() {
    print_status "Resolving Swift packages on remote..."

    if ! ssh "${SSH_HOST}" "cd ${REMOTE_PROJECT_PATH} && swift package resolve" 2>&1; then
        print_warning "Package resolution had issues, continuing anyway..."
    fi

    return 0
}

# Run tests on remote
run_tests() {
    print_header "Running Tests on ${SSH_HOST}"

    print_status "Executing: swift test --parallel"
    print_status "Timeout: ${TEST_TIMEOUT} seconds"
    echo ""

    local start_time=$(date +%s)

    # Run tests with timeout and capture exit code properly
    local test_output
    local test_exit_code

    # Use a temp file to capture both output and exit code
    set +e
    test_output=$(timeout "${TEST_TIMEOUT}" ssh "${SSH_HOST}" "cd ${REMOTE_PROJECT_PATH} && swift test --parallel 2>&1; echo \"EXIT_CODE:\$?\"")
    local timeout_exit=$?
    set -e

    # Extract the actual exit code from the output
    if [[ ${timeout_exit} -eq 124 ]]; then
        test_exit_code=124
    else
        test_exit_code=$(echo "${test_output}" | grep -oP 'EXIT_CODE:\K\d+' | tail -1)
        test_output=$(echo "${test_output}" | sed 's/EXIT_CODE:[0-9]*$//')
    fi

    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    # Display test output
    echo "${test_output}"
    echo ""

    # Parse test results
    if [[ ${test_exit_code} -eq 0 ]]; then
        print_success "All tests passed in ${duration}s"
        return 0
    elif [[ ${test_exit_code} -eq 124 ]]; then
        print_error "Tests timed out after ${TEST_TIMEOUT}s"
        return 1
    else
        print_error "Tests failed with exit code ${test_exit_code}"
        return 1
    fi
}

# Main execution
main() {
    local skip_sync=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --no-sync)
                skip_sync=true
                shift
                ;;
            --sync-mode)
                SYNC_MODE="$2"
                shift 2
                ;;
            --sync-mode=*)
                SYNC_MODE="${1#*=}"
                shift
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
                show_help
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                ;;
        esac
    done

    print_header "Remote Test Runner"

    echo -e "${CYAN}Configuration:${NC}"
    echo "  SSH Host:      ${SSH_HOST}"
    echo "  Remote Path:   ${REMOTE_PROJECT_PATH}"
    echo "  Local Path:    ${LOCAL_PROJECT_PATH}"
    echo "  Test Timeout:  ${TEST_TIMEOUT}s"
    echo ""

    # Step 1: Check SSH connection
    if ! check_ssh; then
        exit 3
    fi

    # Step 2: Sync code (unless --no-sync)
    if [[ "${skip_sync}" == "false" ]]; then
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            print_warning "Dry run mode - showing what would be synced:"
        fi

        if ! sync_code; then
            exit 2
        fi

        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            print_status "Dry run complete - no tests executed"
            exit 0
        fi
    else
        print_status "Skipping sync (--no-sync)"
    fi

    # Step 3: Resolve packages
    resolve_packages

    # Step 4: Run tests
    if run_tests; then
        print_header "Result: PASSED"
        exit 0
    else
        print_header "Result: FAILED"
        exit 1
    fi
}

# Run main function
main "$@"
