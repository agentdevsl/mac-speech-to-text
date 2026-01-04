#!/bin/bash
# =============================================================================
# build-app.sh
# =============================================================================
# Creates a macOS .app bundle from Swift Package Manager build
#
# Usage: ./scripts/build-app.sh [options]
#
# Options:
#   --release       Build in release mode (default: debug)
#   --dmg           Also create a DMG installer
#   --open          Open the app after building
#   --clean         Clean build directory before building
#   --sign NAME     Sign with specified identity (use "ad-hoc" for ad-hoc)
#   --sync          Pull latest code from git before building
#   --check-signing Run signing validation only (no build)
#   --help          Show this help message
#
# Signing:
#   If .signing-identity file exists in project root, uses that identity.
#   Otherwise defaults to ad-hoc signing.
#   Create consistent signing with: ./scripts/setup-signing.sh
#
# Output:
#   build/SpeechToText.app     - The macOS application bundle
#   build/SpeechToText.dmg     - DMG installer (if --dmg specified)
#
# Requirements:
#   - macOS 14+
#   - Swift 5.9+
#   - Xcode Command Line Tools
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
APP_NAME="SpeechToText"
BUNDLE_ID="com.speechtotext.app"
VERSION="1.0.0"
BUILD_NUMBER="1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"
BUILD_DIR="${PROJECT_ROOT}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
# Entitlements: use debug entitlements (with get-task-allow) for debug builds
# Release builds use production entitlements (no get-task-allow - App Store requirement)
ENTITLEMENTS_FILE_DEBUG="${PROJECT_ROOT}/SpeechToText.debug.entitlements"
ENTITLEMENTS_FILE_RELEASE="${PROJECT_ROOT}/SpeechToText.entitlements"
ENTITLEMENTS_FILE="${ENTITLEMENTS_FILE_DEBUG}"  # Will be set based on BUILD_CONFIG

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Default options
BUILD_CONFIG="debug"
CREATE_DMG=false
OPEN_APP=false
CLEAN_BUILD=false
SIGN_IDENTITY=""
SYNC_CODE=false
CHECK_SIGNING_ONLY=false
REQUIRE_SIGNING=false  # Set to true to mandate signing (no ad-hoc allowed)

# Check for .signing-identity file
SIGNING_IDENTITY_FILE="${PROJECT_ROOT}/.signing-identity"
SIGNING_FINGERPRINT_FILE="${PROJECT_ROOT}/.signing-fingerprint"
if [ -f "${SIGNING_IDENTITY_FILE}" ]; then
    SIGN_IDENTITY=$(cat "${SIGNING_IDENTITY_FILE}" | tr -d '\n\r\t')
    # Validate file is not empty or whitespace-only
    if [ -z "${SIGN_IDENTITY}" ]; then
        echo -e "${YELLOW}[WARNING]${NC} .signing-identity file is empty - using ad-hoc signing"
        SIGN_IDENTITY=""
    else
        # If .signing-identity exists, require signing (permissions won't persist otherwise)
        REQUIRE_SIGNING=true
    fi
fi

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}============================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}\n"
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

print_info() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

show_help() {
    echo ""
    echo "Usage: ./scripts/build-app.sh [options]"
    echo ""
    echo "Creates a macOS .app bundle from Swift Package Manager build."
    echo ""
    echo "Options:"
    echo "  --release       Build in release mode (default: debug)"
    echo "  --dmg           Also create a DMG installer"
    echo "  --open          Open the app after building"
    echo "  --clean         Clean build directory before building"
    echo "  --sign NAME     Sign with specified identity (use 'ad-hoc' for ad-hoc)"
    echo "  --sync          Pull latest code from git before building"
    echo "  --check-signing Run signing validation only (no build)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/build-app.sh                # Debug build with configured signing"
    echo "  ./scripts/build-app.sh --release      # Release build"
    echo "  ./scripts/build-app.sh --release --dmg # Release + DMG"
    echo "  ./scripts/build-app.sh --check-signing # Validate signing setup"
    echo ""
    exit 0
}

check_macos() {
    if [[ "$(uname -s)" != "Darwin" ]]; then
        print_error "This script must be run on macOS"
        exit 1
    fi
}

check_swift() {
    if ! command -v swift &> /dev/null; then
        print_error "Swift not found. Install Xcode Command Line Tools:"
        echo "  xcode-select --install"
        exit 1
    fi

    local swift_version
    swift_version=$(swift --version 2>&1 | head -1)
    print_info "Swift version: ${swift_version}"
}

# =============================================================================
# T011: Pre-build identity validation function
# =============================================================================
validate_signing_identity() {
    local identity="$1"

    if [ -z "$identity" ] || [ "$identity" = "ad-hoc" ]; then
        return 1  # No valid identity
    fi

    # Check if identity exists in keychain
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "${identity}"; then
        return 0  # Identity found
    else
        return 1  # Identity not found
    fi
}

# =============================================================================
# Certificate fingerprint functions for consistent identity validation
# =============================================================================

# Get SHA-256 fingerprint of a certificate by name
get_certificate_fingerprint() {
    local identity="$1"

    if [ -z "$identity" ] || [ "$identity" = "ad-hoc" ]; then
        echo ""
        return 1
    fi

    # Get certificate and compute SHA-256 fingerprint
    local cert_pem
    cert_pem=$(security find-certificate -c "${identity}" -p 2>/dev/null)

    if [ -z "$cert_pem" ]; then
        echo ""
        return 1
    fi

    # Compute SHA-256 fingerprint
    local fingerprint
    fingerprint=$(echo "$cert_pem" | openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/.*=//' | tr -d ':')

    echo "$fingerprint"
}

# Store fingerprint for future validation
store_certificate_fingerprint() {
    local identity="$1"
    local fingerprint
    fingerprint=$(get_certificate_fingerprint "$identity")

    if [ -n "$fingerprint" ]; then
        echo "$fingerprint" > "${SIGNING_FINGERPRINT_FILE}"
        print_success "Stored certificate fingerprint: ${fingerprint:0:16}..."
        return 0
    else
        print_error "Could not get certificate fingerprint"
        return 1
    fi
}

# Validate current certificate matches stored fingerprint
validate_certificate_fingerprint() {
    local identity="$1"

    # If no fingerprint file exists, store the current one
    if [ ! -f "${SIGNING_FINGERPRINT_FILE}" ]; then
        print_info "No stored fingerprint found - storing current certificate fingerprint"
        store_certificate_fingerprint "$identity"
        return $?
    fi

    # Get stored fingerprint
    local stored_fingerprint
    stored_fingerprint=$(cat "${SIGNING_FINGERPRINT_FILE}" | tr -d '\n\r\t ')

    if [ -z "$stored_fingerprint" ]; then
        print_warning "Stored fingerprint is empty - storing current certificate fingerprint"
        store_certificate_fingerprint "$identity"
        return $?
    fi

    # Get current fingerprint
    local current_fingerprint
    current_fingerprint=$(get_certificate_fingerprint "$identity")

    if [ -z "$current_fingerprint" ]; then
        print_error "Could not get fingerprint for certificate '${identity}'"
        return 1
    fi

    # Compare
    if [ "$stored_fingerprint" = "$current_fingerprint" ]; then
        print_success "Certificate fingerprint validated: ${current_fingerprint:0:16}..."
        return 0
    else
        print_error "Certificate fingerprint MISMATCH!"
        echo ""
        echo "  Stored:  ${stored_fingerprint:0:32}..."
        echo "  Current: ${current_fingerprint:0:32}..."
        echo ""
        echo "  This means the signing certificate has changed since last build."
        echo "  macOS TCC will treat this as a DIFFERENT application and"
        echo "  permissions (Microphone, Accessibility) will be LOST."
        echo ""
        echo "  Remediation:"
        echo "    1. If you intentionally changed the certificate:"
        echo "       rm ${SIGNING_FINGERPRINT_FILE}"
        echo "       ./scripts/build-app.sh   # Will store new fingerprint"
        echo ""
        echo "    2. If this is unexpected, recreate the original certificate:"
        echo "       ./scripts/setup-signing.sh --force"
        echo ""
        return 1
    fi
}

# Verify app signature after build
verify_app_signature() {
    local app_path="$1"
    local expected_identity="$2"

    print_info "Verifying app signature..."

    # Basic signature validation
    if ! codesign --verify --deep --strict "${app_path}" 2>/dev/null; then
        print_error "App signature verification failed!"
        return 1
    fi

    # Get the designated requirement
    local designated_req
    designated_req=$(codesign -d -r- "${app_path}" 2>&1 | grep "designated =>" | sed 's/.*designated => //')

    if [ -z "$designated_req" ]; then
        print_warning "Could not extract designated requirement"
        return 0  # Non-fatal
    fi

    # Verify bundle identifier is correct
    if echo "$designated_req" | grep -q "identifier \"${BUNDLE_ID}\""; then
        print_success "Bundle identifier verified: ${BUNDLE_ID}"
    else
        print_error "Bundle identifier mismatch in signature!"
        echo "  Expected: ${BUNDLE_ID}"
        echo "  Got: ${designated_req}"
        return 1
    fi

    # Verify the identity if not ad-hoc
    if [ -n "$expected_identity" ] && [ "$expected_identity" != "ad-hoc" ]; then
        # Check that certificate is in the requirement
        local identity_in_req
        identity_in_req=$(codesign -d -r- "${app_path}" 2>&1 | grep -c "${expected_identity}" || true)

        if [ "$identity_in_req" -gt 0 ]; then
            print_success "Signing identity verified in designated requirement"
        else
            # This is just informational - the cert name might not appear literally
            print_info "Signature uses certificate root hash (expected for self-signed)"
        fi
    fi

    print_success "App signature verified successfully"
    return 0
}

# =============================================================================
# T012: --check-signing flag implementation
# =============================================================================
check_signing_configuration() {
    echo ""
    echo -e "${BOLD}${CYAN}Checking Code Signing Configuration${NC}"
    echo ""

    local has_issues=false

    # Check for .signing-identity file
    if [ -f "${SIGNING_IDENTITY_FILE}" ]; then
        local stored_identity
        stored_identity=$(cat "${SIGNING_IDENTITY_FILE}" | tr -d '\n')
        print_success "Found .signing-identity file: ${stored_identity}"

        # Validate the identity in keychain
        if validate_signing_identity "${stored_identity}"; then
            print_success "Identity '${stored_identity}' found in keychain"

            # Check certificate details
            local cert_info
            cert_info=$(security find-certificate -c "${stored_identity}" -p 2>/dev/null || echo "")
            if [ -n "$cert_info" ]; then
                # Try to get expiration
                local expiry_date
                expiry_date=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "Unknown")
                print_info "Certificate expires: ${expiry_date}"
            fi

            # Check fingerprint file and validation
            if [ -f "${SIGNING_FINGERPRINT_FILE}" ]; then
                local stored_fp
                stored_fp=$(cat "${SIGNING_FINGERPRINT_FILE}" | tr -d '\n\r\t ')
                local current_fp
                current_fp=$(get_certificate_fingerprint "${stored_identity}")

                if [ -n "$stored_fp" ] && [ -n "$current_fp" ]; then
                    if [ "$stored_fp" = "$current_fp" ]; then
                        print_success "Fingerprint file found and matches: ${stored_fp:0:16}..."
                    else
                        print_error "Fingerprint MISMATCH!"
                        echo "  Stored:  ${stored_fp:0:32}..."
                        echo "  Current: ${current_fp:0:32}..."
                        has_issues=true
                    fi
                else
                    print_warning "Could not validate fingerprint"
                    has_issues=true
                fi
            else
                print_warning "No .signing-fingerprint file found"
                echo "  Will be created on first build with this identity"
            fi
        else
            print_error "Identity '${stored_identity}' NOT found in keychain!"
            echo ""
            echo "  The .signing-identity file references a certificate that doesn't exist."
            echo ""
            echo "  Remediation:"
            echo "    1. Run setup to create the certificate:"
            echo "       ./scripts/setup-signing.sh"
            echo ""
            echo "    2. Or recreate if it expired:"
            echo "       ./scripts/setup-signing.sh --force"
            echo ""
            has_issues=true
        fi
    else
        print_warning "No .signing-identity file found"
        echo ""
        echo "  Builds will use ad-hoc signing. Permissions will NOT persist across rebuilds."
        echo ""
        echo "  Remediation: Set up persistent code signing:"
        echo "    ./scripts/setup-signing.sh"
        echo ""
        has_issues=true
    fi

    # Check release entitlements file (production)
    if [ -f "${ENTITLEMENTS_FILE_RELEASE}" ]; then
        print_success "Release entitlements found: ${ENTITLEMENTS_FILE_RELEASE}"

        # Verify key entitlements
        if grep -q "com.apple.security.device.microphone" "${ENTITLEMENTS_FILE_RELEASE}"; then
            print_success "  Microphone entitlement present"
        else
            print_warning "  Microphone entitlement MISSING"
            has_issues=true
        fi

        if grep -q "com.apple.security.personal-information.accessibility" "${ENTITLEMENTS_FILE_RELEASE}"; then
            print_success "  Accessibility entitlement present"
        else
            print_warning "  Accessibility entitlement MISSING"
            has_issues=true
        fi

        # Verify NO get-task-allow in release (App Store requirement)
        if grep -q "com.apple.security.get-task-allow" "${ENTITLEMENTS_FILE_RELEASE}"; then
            print_warning "  get-task-allow present (should be removed for App Store)"
        else
            print_success "  get-task-allow correctly absent (App Store compatible)"
        fi
    else
        print_error "Release entitlements file not found: ${ENTITLEMENTS_FILE_RELEASE}"
        has_issues=true
    fi

    # Check debug entitlements file
    if [ -f "${ENTITLEMENTS_FILE_DEBUG}" ]; then
        print_success "Debug entitlements found: ${ENTITLEMENTS_FILE_DEBUG}"

        # Verify get-task-allow is present for debugging
        if grep -q "com.apple.security.get-task-allow" "${ENTITLEMENTS_FILE_DEBUG}"; then
            print_success "  get-task-allow present (enables debugger attach)"
        else
            print_warning "  get-task-allow MISSING (may affect debugger attachment)"
            has_issues=true
        fi
    else
        print_warning "Debug entitlements file not found: ${ENTITLEMENTS_FILE_DEBUG}"
        echo "  Debug builds will use release entitlements (no get-task-allow)"
    fi

    echo ""
    if [ "$has_issues" = true ]; then
        print_warning "Signing configuration has issues - see above for remediation"
        return 1
    else
        print_success "Signing configuration is valid"
        return 0
    fi
}

# =============================================================================
# T013 & T014: Prominent ad-hoc signing warning
# =============================================================================
show_adhoc_warning() {
    echo ""
    echo -e "${YELLOW}============================================================================${NC}"
    echo -e "${YELLOW}${BOLD}                    AD-HOC SIGNING WARNING${NC}"
    echo -e "${YELLOW}============================================================================${NC}"
    echo ""
    echo -e "${YELLOW}  You are using AD-HOC signing.${NC}"
    echo ""
    echo "  This means:"
    echo "    - Permissions (Microphone, Accessibility) will NOT persist"
    echo "    - You will need to re-grant permissions after EVERY rebuild"
    echo "    - macOS TCC treats each build as a completely new application"
    echo ""
    echo "  To enable persistent permissions, set up code signing:"
    echo ""
    echo -e "    ${CYAN}./scripts/setup-signing.sh${NC}"
    echo ""
    echo "  This creates a self-signed certificate that ensures macOS"
    echo "  recognizes your app consistently across builds."
    echo ""
    echo -e "${YELLOW}============================================================================${NC}"
    echo ""
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        --release)
            BUILD_CONFIG="release"
            shift
            ;;
        --dmg)
            CREATE_DMG=true
            shift
            ;;
        --open)
            OPEN_APP=true
            shift
            ;;
        --clean)
            CLEAN_BUILD=true
            shift
            ;;
        --sign)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                print_error "--sign requires an identity name"
                exit 1
            fi
            SIGN_IDENTITY="$2"
            shift 2
            ;;
        --sync)
            SYNC_CODE=true
            shift
            ;;
        --check-signing)
            CHECK_SIGNING_ONLY=true
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

# =============================================================================
# Select entitlements file based on build configuration
# =============================================================================
# Debug builds get get-task-allow (allows debugger attach, matches Xcode behavior)
# Release builds strip get-task-allow (required for App Store / notarization)

if [ "$BUILD_CONFIG" = "release" ]; then
    ENTITLEMENTS_FILE="${ENTITLEMENTS_FILE_RELEASE}"
    print_info "Using release entitlements (no get-task-allow)"
else
    ENTITLEMENTS_FILE="${ENTITLEMENTS_FILE_DEBUG}"
    print_info "Using debug entitlements (with get-task-allow for debugger attach)"
fi

# Verify entitlements file exists
if [ ! -f "${ENTITLEMENTS_FILE}" ]; then
    print_error "Entitlements file not found: ${ENTITLEMENTS_FILE}"
    echo ""
    echo "  Expected entitlements files:"
    echo "    Debug:   ${ENTITLEMENTS_FILE_DEBUG}"
    echo "    Release: ${ENTITLEMENTS_FILE_RELEASE}"
    echo ""
    exit 1
fi

# =============================================================================
# Handle --check-signing flag (T012)
# =============================================================================

if [ "$CHECK_SIGNING_ONLY" = true ]; then
    check_macos
    check_signing_configuration
    exit $?
fi

# =============================================================================
# Main Build Process
# =============================================================================

print_header "Building ${APP_NAME} for Local Testing"

# Verify environment
check_macos
check_swift

# T011: Pre-build identity validation with fingerprint enforcement
echo ""
print_info "Validating signing configuration..."

# Check if signing is required but not configured
if [ "${REQUIRE_SIGNING}" = true ] && { [ -z "${SIGN_IDENTITY}" ] || [ "${SIGN_IDENTITY}" = "ad-hoc" ]; }; then
    print_error "Code signing is REQUIRED but no valid signing identity is configured!"
    echo ""
    echo "  A .signing-identity file exists, which means this project requires"
    echo "  consistent code signing for permissions to persist across builds."
    echo ""
    echo "  Remediation:"
    echo "    1. Set up code signing certificate:"
    echo "       ./scripts/setup-signing.sh"
    echo ""
    echo "    2. Or check why the identity file is invalid:"
    echo "       cat .signing-identity"
    echo ""
    exit 1
fi

if [ -n "${SIGN_IDENTITY}" ] && [ "${SIGN_IDENTITY}" != "ad-hoc" ]; then
    # Validate identity exists in keychain
    if validate_signing_identity "${SIGN_IDENTITY}"; then
        print_success "Signing identity '${SIGN_IDENTITY}' found in keychain"
    else
        print_error "Signing identity '${SIGN_IDENTITY}' not found in keychain!"
        echo ""
        echo "  The configured signing identity doesn't exist."
        echo ""
        echo "  Remediation options:"
        echo "    1. Create the certificate:"
        echo "       ./scripts/setup-signing.sh --name \"${SIGN_IDENTITY}\""
        echo ""
        echo "    2. Check available identities:"
        echo "       security find-identity -v -p codesigning"
        echo ""
        echo "    3. Use default identity:"
        echo "       rm .signing-identity && ./scripts/setup-signing.sh"
        echo ""
        exit 1
    fi

    # Validate certificate fingerprint matches stored fingerprint
    # This ensures the same certificate is used across builds
    if ! validate_certificate_fingerprint "${SIGN_IDENTITY}"; then
        print_error "Certificate fingerprint validation failed!"
        echo ""
        echo "  Build aborted to prevent permission loss."
        echo "  See remediation steps above."
        echo ""
        exit 1
    fi
else
    # Check if fingerprint file exists but we're using ad-hoc
    if [ -f "${SIGNING_FINGERPRINT_FILE}" ]; then
        print_error "Fingerprint file exists but no signing identity configured!"
        echo ""
        echo "  This project was previously built with a signing certificate."
        echo "  Building with ad-hoc signing will break permission persistence."
        echo ""
        echo "  Remediation:"
        echo "    1. Restore the signing certificate:"
        echo "       ./scripts/setup-signing.sh"
        echo ""
        echo "    2. Or clear the fingerprint to start fresh (permissions will be lost):"
        echo "       rm ${SIGNING_FINGERPRINT_FILE}"
        echo ""
        exit 1
    fi

    # T013 & T014: Show prominent ad-hoc warning
    show_adhoc_warning
fi

cd "${PROJECT_ROOT}"

# Kill running app before building to prevent conflicts
if pgrep -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" > /dev/null 2>&1; then
    print_info "Stopping running ${APP_NAME} app..."
    pkill -f "${APP_NAME}.app/Contents/MacOS/${APP_NAME}" 2>/dev/null || true
    sleep 1
    print_success "App stopped"
fi

# Sync code from git if requested
if [ "$SYNC_CODE" = true ]; then
    print_info "Syncing code from git..."
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Check for uncommitted changes and warn user
        if [ -n "$(git status --porcelain)" ]; then
            print_warning "Uncommitted changes detected!"
            echo ""
            echo "  --sync will discard ALL uncommitted changes (staged and unstaged)."
            echo "  This operation cannot be undone."
            echo ""
            # Check if running interactively (TTY available)
            if [ -t 0 ]; then
                echo -n "  Continue? (y/N): "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    print_info "Sync cancelled. Commit or stash your changes first."
                    exit 0
                fi
            else
                print_error "Cannot prompt for confirmation in non-interactive mode"
                print_info "Stash or commit changes before using --sync in CI/scripts"
                exit 1
            fi
        fi
        git fetch origin
        git reset --hard origin/main
        print_success "Code synced from origin/main"
    else
        print_warning "Not a git repository, skipping sync"
    fi
fi

# Clean if requested
if [ "$CLEAN_BUILD" = true ]; then
    print_info "Cleaning build caches..."

    # Clean local build directory
    rm -rf "${BUILD_DIR}" 2>/dev/null || true
    print_success "Cleaned build/"

    # Try to clean .build but don't fail if locked by another process
    rm -rf .build 2>/dev/null || {
        print_warning "Could not fully clean .build directory (may be in use)"
        # Try cleaning just the build artifacts, leave checkouts/dependencies
        rm -rf .build/arm64-apple-macosx 2>/dev/null || true
        rm -rf .build/debug 2>/dev/null || true
        rm -rf .build/release 2>/dev/null || true
    }
    print_success "Cleaned .build/"

    # Clean Xcode DerivedData for this project
    rm -rf "${HOME}/Library/Developer/Xcode/DerivedData/SpeechToText-"* 2>/dev/null || true
    rm -rf "${HOME}/Library/Developer/Xcode/DerivedData/mac-speech-to-text-"* 2>/dev/null || true
    print_success "Cleaned Xcode DerivedData"

    # Clean SwiftPM cache (optional - can slow rebuilds)
    rm -rf "${HOME}/Library/Caches/org.swift.swiftpm" 2>/dev/null || true
    print_success "Cleaned SwiftPM cache"

    print_success "All build caches cleaned"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# =============================================================================
# Build with xcodebuild
# =============================================================================

DERIVED_DATA="${BUILD_DIR}/DerivedData"
XCODE_CONFIG="Debug"
if [ "$BUILD_CONFIG" = "release" ]; then
    XCODE_CONFIG="Release"
fi

print_info "Building ${BUILD_CONFIG} configuration with xcodebuild..."

# Build using xcodebuild with the workspace
# Pass our entitlements so xcodebuild signs with them directly
xcodebuild \
    -workspace "${PROJECT_ROOT}/SpeechToText.xcworkspace" \
    -scheme "SpeechToText" \
    -configuration "${XCODE_CONFIG}" \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="${SIGN_IDENTITY:-"-"}" \
    CODE_SIGN_STYLE="Manual" \
    CODE_SIGN_ENTITLEMENTS="${ENTITLEMENTS_FILE}" \
    DEVELOPMENT_TEAM="" \
    2>&1 | tee "${BUILD_DIR}/build.log"

BUILD_RESULT=${PIPESTATUS[0]}
if [ $BUILD_RESULT -ne 0 ]; then
    print_error "Build failed. Check ${BUILD_DIR}/build.log"
    exit 1
fi
print_success "Build completed successfully"

# =============================================================================
# Create App Bundle from Executable
# =============================================================================

print_header "Creating App Bundle"

# xcodebuild with SPM produces an executable, not an .app bundle
# We need to manually create the bundle structure
XCODE_EXECUTABLE="${DERIVED_DATA}/Build/Products/${XCODE_CONFIG}/SpeechToText"
if [ ! -f "${XCODE_EXECUTABLE}" ]; then
    print_error "Built executable not found at ${XCODE_EXECUTABLE}"
    exit 1
fi
print_success "Found executable: ${XCODE_EXECUTABLE}"

# Remove old bundle and create new structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${XCODE_EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
print_success "Copied executable to app bundle"

# Create Info.plist
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}.${COMMIT_HASH}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2024. All rights reserved.</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.productivity</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>SpeechToText needs microphone access to convert your speech to text.</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF
print_success "Created Info.plist"

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
print_success "Created PkgInfo"

# Copy app icon if exists
if [ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    print_success "Copied app icon"
elif [ -f "${PROJECT_ROOT}/Sources/SpeechToTextApp/Resources/AppIcon.icns" ]; then
    cp "${PROJECT_ROOT}/Sources/SpeechToTextApp/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/"
    print_success "Copied app icon"
fi

# Set permissions
chmod -R 755 "${APP_BUNDLE}"

# =============================================================================
# Code Signing
# =============================================================================

print_header "Code Signing"

if [ -n "${SIGN_IDENTITY}" ] && [ "${SIGN_IDENTITY}" != "ad-hoc" ]; then
    print_info "Signing with identity: ${SIGN_IDENTITY}"
    if [ -f "${ENTITLEMENTS_FILE}" ]; then
        codesign --force --deep --sign "${SIGN_IDENTITY}" \
            --entitlements "${ENTITLEMENTS_FILE}" \
            --options runtime \
            "${APP_BUNDLE}" 2>&1 || {
            print_error "Code signing failed!"
            echo ""
            echo "  Possible causes:"
            echo "    - Certificate not trusted for code signing"
            echo "    - Keychain access denied"
            echo "    - Certificate has expired"
            echo ""
            echo "  Remediation:"
            echo "    1. Check available identities:"
            echo "       security find-identity -v -p codesigning"
            echo ""
            echo "    2. Verify identity status:"
            echo "       ./scripts/setup-signing.sh --verify"
            echo ""
            echo "    3. Recreate if needed:"
            echo "       ./scripts/setup-signing.sh --force"
            echo ""
            exit 1
        }
    else
        codesign --force --deep --sign "${SIGN_IDENTITY}" \
            --options runtime \
            "${APP_BUNDLE}" 2>&1 || {
            print_error "Code signing failed"
            exit 1
        }
    fi
    print_success "Signed with: ${SIGN_IDENTITY}"
    print_success "Entitlements applied - permissions will persist across rebuilds"
else
    print_info "Ad-hoc signing for local testing..."
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || {
        print_warning "Could not ad-hoc sign app (may require Xcode)"
    }
    print_warning "Ad-hoc signed - permissions will NOT persist across rebuilds"
fi
print_success "App bundle created"

# Post-build signature verification
if [ -n "${SIGN_IDENTITY}" ] && [ "${SIGN_IDENTITY}" != "ad-hoc" ]; then
    if ! verify_app_signature "${APP_BUNDLE}" "${SIGN_IDENTITY}"; then
        print_error "Post-build signature verification failed!"
        echo ""
        echo "  The app was signed but verification failed. This may indicate"
        echo "  a signing issue that could affect permission persistence."
        echo ""
        exit 1
    fi
fi

# =============================================================================
# Gatekeeper bypass for development (free developer account workaround)
# =============================================================================
# Apps signed with free/personal team certificates are not notarized and will be
# blocked by Gatekeeper on first launch. Remove quarantine flag to bypass this.
# This is safe for local development and matches Xcode's behavior.

print_info "Removing Gatekeeper quarantine flag (development build)..."
xattr -rd com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true
print_success "Gatekeeper bypass applied (local development only)"

# =============================================================================
# Create DMG (if requested)
# =============================================================================

if [ "$CREATE_DMG" = true ]; then
    print_header "Creating DMG Installer"

    DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
    DMG_TEMP="${BUILD_DIR}/dmg_temp"

    # Clean up
    rm -rf "${DMG_TEMP}"
    rm -f "${DMG_PATH}"

    # Create temp directory
    mkdir -p "${DMG_TEMP}"

    # Copy app
    cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"

    # Create Applications symlink
    ln -s /Applications "${DMG_TEMP}/Applications"

    # Create DMG
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${DMG_TEMP}" \
        -ov -format UDZO \
        "${DMG_PATH}" 2>/dev/null

    # Clean up
    rm -rf "${DMG_TEMP}"

    print_success "DMG created: ${DMG_PATH}"
    print_info "Size: $(du -h "${DMG_PATH}" | cut -f1)"
fi

# =============================================================================
# Summary
# =============================================================================

print_header "Build Complete"

echo -e "${GREEN}[SUCCESS]${NC} App Bundle: ${APP_BUNDLE}"
if [ "$CREATE_DMG" = true ]; then
    echo -e "${GREEN}[SUCCESS]${NC} DMG File:   ${BUILD_DIR}/${APP_NAME}.dmg"
fi
echo ""
echo -e "${CYAN}To run the app:${NC}"
echo "  open ${APP_BUNDLE}"
echo ""

# Show appropriate note based on signing
if [ -n "${SIGN_IDENTITY}" ] && [ "${SIGN_IDENTITY}" != "ad-hoc" ]; then
    echo -e "${GREEN}Signing:${NC} Using '${SIGN_IDENTITY}' - permissions will persist"
    echo ""
    echo "First launch:"
    echo "  1. Grant Microphone permission when prompted"
    echo "  2. Grant Accessibility in System Settings > Privacy & Security"
    echo "  3. Rebuild anytime - permissions will remain granted"
    echo ""
else
    echo -e "${YELLOW}Signing:${NC} Ad-hoc signed (local testing only)"
    echo ""
    echo -e "${YELLOW}Important:${NC} Permissions will be lost on rebuild!"
    echo "  To enable persistent permissions: ./scripts/setup-signing.sh"
    echo ""
fi

# Open app if requested
if [ "$OPEN_APP" = true ]; then
    print_info "Opening app..."
    open "${APP_BUNDLE}"
fi
