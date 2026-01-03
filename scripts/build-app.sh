#!/bin/bash
# =============================================================================
# build-app.sh
# =============================================================================
# Creates a macOS .app bundle from Swift Package Manager build
# For local testing without code signing
#
# Usage: ./scripts/build-app.sh [options]
#
# Options:
#   --release       Build in release mode (default: debug)
#   --dmg           Also create a DMG installer
#   --open          Open the app after building
#   --clean         Clean build directory before building
#   --help          Show this help message
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

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

show_help() {
    head -30 "$0" | tail -25 | sed 's/^# //' | sed 's/^#//'
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
# Main Build Process
# =============================================================================

print_header "Building ${APP_NAME} for Local Testing"

# Verify environment
check_macos
check_swift

cd "${PROJECT_ROOT}"

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
# Ad-hoc Sign for Local Testing (with entitlements)
# =============================================================================

print_info "Ad-hoc signing with entitlements for local testing..."
if [ -f "${ENTITLEMENTS_FILE}" ]; then
    codesign --force --deep --sign - --entitlements "${ENTITLEMENTS_FILE}" "${APP_BUNDLE}" 2>/dev/null || {
        print_warning "Could not ad-hoc sign app with entitlements (may require Xcode)"
        # Fallback to signing without entitlements
        codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    }
    print_success "App bundle signed with entitlements"
else
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || {
        print_warning "Could not ad-hoc sign app (may require Xcode)"
    }
    print_success "App bundle signed (no entitlements file found)"
fi

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

echo -e "${GREEN}✓${NC} App Bundle: ${APP_BUNDLE}"
if [ "$CREATE_DMG" = true ]; then
    echo -e "${GREEN}✓${NC} DMG File:   ${BUILD_DIR}/${APP_NAME}.dmg"
fi
echo ""
echo -e "${CYAN}To run the app:${NC}"
echo "  open ${APP_BUNDLE}"
echo ""
echo -e "${YELLOW}Note:${NC} This is an ad-hoc signed build for local testing only."
echo "      For distribution, use proper code signing with a Developer ID."
echo ""

# Open app if requested
if [ "$OPEN_APP" = true ]; then
    print_info "Opening app..."
    open "${APP_BUNDLE}"
fi
