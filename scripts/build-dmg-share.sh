#!/bin/bash
# =============================================================================
# build-dmg-share.sh
# =============================================================================
# Creates a signed macOS .app bundle and DMG for sharing with colleagues.
# Uses a self-signed certificate (10-year validity) for consistent app identity.
# No Apple Developer account required.
#
# Usage: ./scripts/build-dmg-share.sh [--recreate-cert]
#
# Options:
#   --recreate-cert  Force recreation of the signing certificate
#
# Output:
#   build/SpeechToText.app     - The macOS application bundle
#   build/SpeechToText.dmg     - DMG installer for sharing
#
# Requirements:
#   - macOS 14+
#   - Swift 5.9+ / Xcode Command Line Tools
#
# Note for recipients:
#   On first launch, right-click the app and select "Open" to bypass Gatekeeper,
#   or go to System Settings > Privacy & Security to allow the app.
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
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
ENTITLEMENTS_FILE="${PROJECT_ROOT}/SpeechToText.entitlements"

# Self-signed certificate identity (10-year validity, no Apple account needed)
# Uses existing SpeechToText-Dev certificate created by setup-signing.sh
DIST_CERT_NAME="SpeechToText-Dev"

# Parse arguments
RECREATE_CERT=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --recreate-cert)
            RECREATE_CERT=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./scripts/build-dmg-share.sh [--recreate-cert]"
            exit 1
            ;;
    esac
done

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# =============================================================================
# Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}============================================================================${NC}"
    echo -e "${BOLD}${CYAN}  $1${NC}"
    echo -e "${BLUE}============================================================================${NC}"
    echo ""
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

# =============================================================================
# Pre-flight Checks
# =============================================================================

print_header "Building ${APP_NAME} DMG for Sharing"

# Check macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    print_error "This script must be run on macOS"
    exit 1
fi

# Check Swift
if ! command -v swift &> /dev/null; then
    print_error "Swift not found. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

print_info "Swift version: $(swift --version 2>&1 | head -1)"

# =============================================================================
# Self-Signed Certificate Management
# =============================================================================
# Creates a self-signed certificate with 10-year validity for consistent
# app identity without relying on Apple Developer certificates.

create_self_signed_cert() {
    local cert_name="$1"

    print_info "Creating self-signed certificate: ${cert_name}"
    print_info "Validity: 10 years (3650 days)"

    # Create certificate signing request config
    local csr_config="${BUILD_DIR}/cert_config.txt"
    mkdir -p "${BUILD_DIR}"
    cat > "${csr_config}" << EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = codesign_ext
prompt = no

[req_distinguished_name]
CN = ${cert_name}
O = SpeechToText
OU = Distribution

[codesign_ext]
keyUsage = critical, digitalSignature
extendedKeyUsage = codeSigning
basicConstraints = critical, CA:FALSE
EOF

    # Generate private key and self-signed certificate
    local key_file="${BUILD_DIR}/dist_key.pem"
    local cert_file="${BUILD_DIR}/dist_cert.pem"
    local p12_file="${BUILD_DIR}/dist_cert.p12"

    # Generate 2048-bit RSA key and self-signed cert (10 years = 3650 days)
    openssl req -x509 -newkey rsa:2048 \
        -keyout "${key_file}" \
        -out "${cert_file}" \
        -days 3650 \
        -nodes \
        -config "${csr_config}" \
        2>/dev/null

    # Convert to PKCS12 format for keychain import (empty password for automation)
    openssl pkcs12 -export \
        -out "${p12_file}" \
        -inkey "${key_file}" \
        -in "${cert_file}" \
        -passout pass: \
        2>/dev/null

    # Import into keychain with trust for code signing
    security import "${p12_file}" \
        -k ~/Library/Keychains/login.keychain-db \
        -T /usr/bin/codesign \
        -T /usr/bin/security \
        2>/dev/null || {
        # Try default keychain if specific path fails
        security import "${p12_file}" \
            -T /usr/bin/codesign \
            -T /usr/bin/security \
            2>/dev/null
    }

    # Set certificate as trusted for code signing
    # Note: User may need to manually trust in Keychain Access if this fails
    security add-trusted-cert -d -r trustRoot -k ~/Library/Keychains/login.keychain-db "${cert_file}" 2>/dev/null || {
        print_warning "Could not auto-trust certificate"
        echo "  You may need to manually trust it in Keychain Access:"
        echo "  1. Open Keychain Access"
        echo "  2. Find '${cert_name}' certificate"
        echo "  3. Double-click > Trust > Code Signing: Always Trust"
    }

    # Clean up temp files
    rm -f "${key_file}" "${cert_file}" "${p12_file}" "${csr_config}"

    # Verify certificate was created
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "${cert_name}"; then
        print_success "Certificate created and imported successfully"

        # Show expiry
        local expiry
        expiry=$(security find-certificate -c "${cert_name}" -p 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        print_info "Certificate expires: ${expiry}"
        return 0
    else
        print_error "Failed to create certificate"
        return 1
    fi
}

# Check/create self-signed distribution certificate
SIGN_IDENTITY="${DIST_CERT_NAME}"

if [ "$RECREATE_CERT" = true ]; then
    print_info "Removing existing certificate..."
    security delete-certificate -c "${DIST_CERT_NAME}" 2>/dev/null || true
fi

if security find-identity -v -p codesigning 2>/dev/null | grep -q "${DIST_CERT_NAME}"; then
    print_success "Using existing certificate: ${DIST_CERT_NAME}"

    # Show certificate expiry
    expiry_date=$(security find-certificate -c "${DIST_CERT_NAME}" -p 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "unknown")
    print_info "Certificate expires: ${expiry_date}"
else
    print_info "Distribution certificate not found, creating one..."
    if ! create_self_signed_cert "${DIST_CERT_NAME}"; then
        print_error "Failed to create signing certificate"
        print_info "Falling back to ad-hoc signing (identity will not be consistent)"
        SIGN_IDENTITY=""
    fi
fi

cd "${PROJECT_ROOT}"

# =============================================================================
# Build
# =============================================================================

print_header "Building Release Configuration"

# Clean and create build directory
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build using xcodebuild with workspace
DERIVED_DATA="${BUILD_DIR}/DerivedData"

print_info "Building with xcodebuild..."

xcodebuild \
    -workspace "${PROJECT_ROOT}/SpeechToText.xcworkspace" \
    -scheme "SpeechToText" \
    -configuration "Release" \
    -derivedDataPath "${DERIVED_DATA}" \
    -destination "platform=macOS" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    DEVELOPMENT_TEAM="" \
    2>&1 | tee "${BUILD_DIR}/build.log"

BUILD_RESULT=${PIPESTATUS[0]}
if [ $BUILD_RESULT -ne 0 ]; then
    print_error "Build failed. Check ${BUILD_DIR}/build.log"
    exit 1
fi
print_success "Build completed"

# =============================================================================
# Create App Bundle
# =============================================================================

print_header "Creating App Bundle"

# Find the built executable
XCODE_EXECUTABLE="${DERIVED_DATA}/Build/Products/Release/SpeechToText"
if [ ! -f "${XCODE_EXECUTABLE}" ]; then
    print_error "Built executable not found at ${XCODE_EXECUTABLE}"
    exit 1
fi

# Create bundle structure
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy executable
cp "${XCODE_EXECUTABLE}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
chmod +x "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
print_success "Copied executable"

# Create Info.plist
COMMIT_HASH=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE=$(date +%Y%m%d)
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
    <string>${BUILD_NUMBER}.${BUILD_DATE}.${COMMIT_HASH}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright 2024. All rights reserved.</string>
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

# Copy app icon if exists
if [ -f "${PROJECT_ROOT}/app_logov2.png" ]; then
    print_info "Creating app icon..."
    ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
    mkdir -p "${ICONSET_DIR}"

    # Create icon sizes
    sips -z 16 16     "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_16x16.png" 2>/dev/null || true
    sips -z 32 32     "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_16x16@2x.png" 2>/dev/null || true
    sips -z 32 32     "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_32x32.png" 2>/dev/null || true
    sips -z 64 64     "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_32x32@2x.png" 2>/dev/null || true
    sips -z 128 128   "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_128x128.png" 2>/dev/null || true
    sips -z 256 256   "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_128x128@2x.png" 2>/dev/null || true
    sips -z 256 256   "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_256x256.png" 2>/dev/null || true
    sips -z 512 512   "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_256x256@2x.png" 2>/dev/null || true
    sips -z 512 512   "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_512x512.png" 2>/dev/null || true
    sips -z 1024 1024 "${PROJECT_ROOT}/app_logov2.png" --out "${ICONSET_DIR}/icon_512x512@2x.png" 2>/dev/null || true

    iconutil -c icns "${ICONSET_DIR}" -o "${APP_BUNDLE}/Contents/Resources/AppIcon.icns" 2>/dev/null || true
    rm -rf "${ICONSET_DIR}"
    print_success "Created app icon"
fi

# Copy app logo for About section
if [ -f "${PROJECT_ROOT}/app_logov2.png" ]; then
    cp "${PROJECT_ROOT}/app_logov2.png" "${APP_BUNDLE}/Contents/Resources/"
fi

# Copy SPM resource bundles (voice trigger models and dependencies)
# When using xcodebuild, bundles are in DerivedData, not .build/
SPM_BUNDLE="${DERIVED_DATA}/Build/Products/Release/SpeechToText_SpeechToText.bundle"
if [ -d "${SPM_BUNDLE}" ]; then
    cp -R "${SPM_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
    print_success "Copied voice trigger models"
else
    print_warning "SPM bundle not found at: ${SPM_BUNDLE}"
    # Fallback to swift build location if someone ran swift build
    FALLBACK_BUNDLE="${PROJECT_ROOT}/.build/release/SpeechToText_SpeechToText.bundle"
    if [ -d "${FALLBACK_BUNDLE}" ]; then
        cp -R "${FALLBACK_BUNDLE}" "${APP_BUNDLE}/Contents/Resources/"
        print_success "Copied voice trigger models (from .build)"
    else
        print_error "Voice trigger models bundle not found! App may crash on launch."
    fi
fi

# Set permissions
chmod -R 755 "${APP_BUNDLE}"

# =============================================================================
# Code Signing
# =============================================================================

print_header "Signing App Bundle"

if [ -n "${SIGN_IDENTITY}" ]; then
    print_info "Signing with: ${SIGN_IDENTITY}"

    # Sign with certificate and entitlements
    if [ -f "${ENTITLEMENTS_FILE}" ]; then
        codesign --force --deep --sign "${SIGN_IDENTITY}" \
            --entitlements "${ENTITLEMENTS_FILE}" \
            --options runtime \
            "${APP_BUNDLE}" 2>&1 || {
            print_error "Code signing failed!"
            echo "  The certificate may need to be trusted in Keychain Access:"
            echo "  1. Open Keychain Access"
            echo "  2. Find '${SIGN_IDENTITY}' certificate"
            echo "  3. Double-click > Trust > Code Signing: Always Trust"
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
    print_success "App signed with: ${SIGN_IDENTITY}"
else
    print_warning "Using ad-hoc signing (no consistent identity)"
    codesign --force --deep --sign - "${APP_BUNDLE}" 2>/dev/null || true
    print_success "App ad-hoc signed"
fi

# Verify signature
print_info "Verifying signature..."
if codesign --verify --deep --strict "${APP_BUNDLE}" 2>/dev/null; then
    print_success "Signature verified"
else
    print_warning "Signature verification had warnings (may still work)"
fi

# Remove quarantine flag
xattr -rd com.apple.quarantine "${APP_BUNDLE}" 2>/dev/null || true

# =============================================================================
# Create DMG
# =============================================================================

print_header "Creating DMG Installer"

DMG_TEMP="${BUILD_DIR}/dmg_temp"
rm -rf "${DMG_TEMP}"
rm -f "${DMG_PATH}"

# Create temp directory with app and Applications link
mkdir -p "${DMG_TEMP}"
cp -R "${APP_BUNDLE}" "${DMG_TEMP}/"
ln -s /Applications "${DMG_TEMP}/Applications"

# Create a README for the recipient
cat > "${DMG_TEMP}/README.txt" << 'EOF'
SpeechToText - Local Speech-to-Text for macOS
==============================================

Installation:
1. Drag SpeechToText.app to the Applications folder
2. Open the app from Applications
3. If blocked by Gatekeeper:
   - Right-click the app and select "Open", OR
   - Go to System Settings > Privacy & Security and click "Open Anyway"

First Launch:
1. Grant Microphone permission when prompted
2. Grant Accessibility permission in System Settings > Privacy & Security
   (Required for automatic text insertion)

Usage:
- The app runs in the menu bar (look for the microphone icon)
- Press your configured hotkey to start recording
- Release to transcribe and insert text at cursor

For issues or feedback, contact the developer.
EOF

# Create compressed DMG
print_info "Creating compressed DMG..."
hdiutil create -volname "${APP_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    -imagekey zlib-level=9 \
    "${DMG_PATH}" 2>/dev/null

# Clean up
rm -rf "${DMG_TEMP}"

print_success "DMG created: ${DMG_PATH}"

# =============================================================================
# Summary
# =============================================================================

print_header "Build Complete!"

DMG_SIZE=$(du -h "${DMG_PATH}" | cut -f1)

echo -e "${GREEN}[SUCCESS]${NC} App Bundle: ${APP_BUNDLE}"
echo -e "${GREEN}[SUCCESS]${NC} DMG File:   ${DMG_PATH}"
echo -e "${GREEN}[SUCCESS]${NC} DMG Size:   ${DMG_SIZE}"
echo ""

if [ -n "${SIGN_IDENTITY}" ]; then
    echo -e "${GREEN}Signing:${NC} ${SIGN_IDENTITY} (10-year validity)"
    echo -e "${GREEN}Bundle ID:${NC} ${BUNDLE_ID}"
    echo ""
    echo "  The app has a consistent identity. Future builds with this script"
    echo "  will use the same certificate, so the app will be recognized as"
    echo "  the same application by macOS."
    echo ""
fi

echo -e "${CYAN}To share with colleagues:${NC}"
echo "  1. Send them the file: ${DMG_PATH}"
echo "  2. They should drag the app to Applications"
echo "  3. Right-click and select 'Open' on first launch (Gatekeeper bypass)"
echo ""
echo -e "${YELLOW}Note for recipients:${NC}"
echo "  - Right-click > Open (or allow in System Settings > Privacy & Security)"
echo "  - Grant Microphone and Accessibility permissions on first use"
echo ""
