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
ENTITLEMENTS_FILE="${PROJECT_ROOT}/SpeechToText.entitlements"

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

# Check for .signing-identity file
SIGNING_IDENTITY_FILE="${PROJECT_ROOT}/.signing-identity"
if [ -f "${SIGNING_IDENTITY_FILE}" ]; then
    SIGN_IDENTITY=$(cat "${SIGNING_IDENTITY_FILE}" | tr -d '\n\r\t ')
    # Validate file is not empty or whitespace-only
    if [ -z "${SIGN_IDENTITY}" ]; then
        echo -e "${YELLOW}[WARNING]${NC} .signing-identity file is empty - using ad-hoc signing"
        SIGN_IDENTITY=""
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

    # Check entitlements file
    if [ -f "${ENTITLEMENTS_FILE}" ]; then
        print_success "Entitlements file found: ${ENTITLEMENTS_FILE}"

        # Verify key entitlements
        if grep -q "com.apple.security.device.microphone" "${ENTITLEMENTS_FILE}"; then
            print_success "  Microphone entitlement present"
        else
            print_warning "  Microphone entitlement MISSING"
            has_issues=true
        fi

        if grep -q "com.apple.security.personal-information.accessibility" "${ENTITLEMENTS_FILE}"; then
            print_success "  Accessibility entitlement present"
        else
            print_warning "  Accessibility entitlement MISSING"
            has_issues=true
        fi
    else
        print_error "Entitlements file not found: ${ENTITLEMENTS_FILE}"
        has_issues=true
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

# T011: Pre-build identity validation
echo ""
print_info "Validating signing configuration..."
if [ -n "${SIGN_IDENTITY}" ] && [ "${SIGN_IDENTITY}" != "ad-hoc" ]; then
    if validate_signing_identity "${SIGN_IDENTITY}"; then
        print_success "Signing identity '${SIGN_IDENTITY}' validated"
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
else
    # T013 & T014: Show prominent ad-hoc warning
    show_adhoc_warning
fi

cd "${PROJECT_ROOT}"

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
    print_info "Cleaning build directory..."
    rm -rf "${BUILD_DIR}"
    rm -rf .build
    print_success "Build directory cleaned"
fi

# Create build directory
mkdir -p "${BUILD_DIR}"

# Resolve dependencies
print_info "Resolving Swift package dependencies..."
swift package resolve
print_success "Dependencies resolved"

# Build executable
print_info "Building ${BUILD_CONFIG} configuration..."
if [ "$BUILD_CONFIG" = "release" ]; then
    swift build -c release 2>&1 | tee "${BUILD_DIR}/build.log"
    EXECUTABLE_PATH=".build/release/${APP_NAME}"
else
    swift build 2>&1 | tee "${BUILD_DIR}/build.log"
    EXECUTABLE_PATH=".build/debug/${APP_NAME}"
fi

if [ ! -f "${EXECUTABLE_PATH}" ]; then
    print_error "Build failed. Check ${BUILD_DIR}/build.log"
    exit 1
fi
print_success "Build completed successfully"

# =============================================================================
# Create App Bundle
# =============================================================================

print_header "Creating App Bundle"

# Remove old bundle
rm -rf "${APP_BUNDLE}"

# Create bundle structure
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
print_success "Copied executable"

# Create Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>Speech to Text</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSMicrophoneUsageDescription</key>
    <string>Speech-to-Text needs microphone access to capture your voice for transcription.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>Speech-to-Text needs automation access to insert transcribed text into other applications.</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
</dict>
</plist>
EOF
print_success "Created Info.plist"

# Copy entitlements (for reference, not applied without code signing)
if [ -f "${ENTITLEMENTS_FILE}" ]; then
    cp "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}/Contents/Resources/"
    print_success "Copied entitlements"
fi

# Copy icon if available
ICON_SOURCE="${PROJECT_ROOT}/Resources/Assets.xcassets/AppIcon.appiconset"
if [ -d "${ICON_SOURCE}" ]; then
    # Check for existing .icns file or PNG icons
    if [ -f "${PROJECT_ROOT}/Resources/AppIcon.icns" ]; then
        cp "${PROJECT_ROOT}/Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
        print_success "Copied app icon"
    elif [ -f "${PROJECT_ROOT}/app_icon.png" ]; then
        # Convert PNG to icns using sips (built-in macOS tool)
        print_info "Converting app icon to .icns format..."
        ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
        mkdir -p "${ICONSET_DIR}"

        # Create icon sizes
        sips -z 16 16     "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null || true
        sips -z 32 32     "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null || true
        sips -z 32 32     "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null || true
        sips -z 64 64     "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null || true
        sips -z 128 128   "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null || true
        sips -z 256 256   "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null || true
        sips -z 256 256   "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null || true
        sips -z 512 512   "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null || true
        sips -z 512 512   "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null || true
        sips -z 1024 1024 "${PROJECT_ROOT}/app_icon.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null || true

        # Create .icns file
        iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || {
            print_warning "Could not create .icns file (iconutil may not be available)"
        }

        rm -rf "${ICONSET_DIR}"
        print_success "Created app icon"
    else
        print_warning "No app icon found, using default"
    fi
fi

# Create PkgInfo
echo -n "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"
print_success "Created PkgInfo"

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
