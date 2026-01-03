#!/bin/bash
# export-dmg.sh
# Creates a distributable DMG installer for Speech-to-Text app
#
# Task T083: Create DMG installer script for production distribution
#
# Usage: ./scripts/export-dmg.sh [--notarize]
#
# Prerequisites:
# - Xcode 15.0+
# - Valid Apple Developer certificate
# - App archive built with Release configuration
#
# Options:
#   --notarize  Also notarize the DMG for distribution outside App Store

set -euo pipefail

# Configuration
APP_NAME="SpeechToText"
BUNDLE_ID="com.speechtotext.app"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/Export"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
DMG_TEMP="${BUILD_DIR}/dmg_temp"
VOLUME_NAME="${APP_NAME}"

# Parse arguments
NOTARIZE=false
while [[ $# -gt 0 ]]; do
    case $1 in
        --notarize)
            NOTARIZE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "=== ${APP_NAME} DMG Export Script ==="
echo ""

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: Xcode command line tools not found"
    echo "Install with: xcode-select --install"
    exit 1
fi

# Clean build directory
echo "Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Build archive
echo "Building release archive..."
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${APP_NAME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    DEVELOPMENT_TEAM="" \
    2>&1 | tee "${BUILD_DIR}/archive.log"

if [ ! -d "${ARCHIVE_PATH}" ]; then
    echo "Error: Archive failed. Check ${BUILD_DIR}/archive.log"
    exit 1
fi

# Export app
echo "Exporting app from archive..."
cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportPath "${EXPORT_PATH}" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    2>&1 | tee "${BUILD_DIR}/export.log"

APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
if [ ! -d "${APP_PATH}" ]; then
    echo "Error: Export failed. Check ${BUILD_DIR}/export.log"
    exit 1
fi

# Create DMG
echo "Creating DMG installer..."
rm -rf "${DMG_TEMP}"
mkdir -p "${DMG_TEMP}"

# Copy app to temp directory
cp -R "${APP_PATH}" "${DMG_TEMP}/"

# Create symbolic link to Applications folder
ln -s /Applications "${DMG_TEMP}/Applications"

# Create DMG
hdiutil create -volname "${VOLUME_NAME}" \
    -srcfolder "${DMG_TEMP}" \
    -ov -format UDZO \
    "${DMG_PATH}"

# Clean up temp
rm -rf "${DMG_TEMP}"

echo ""
echo "=== DMG Created Successfully ==="
echo "Location: ${DMG_PATH}"
echo "Size: $(du -h "${DMG_PATH}" | cut -f1)"

# Notarize if requested
if [ "$NOTARIZE" = true ]; then
    echo ""
    echo "Notarizing DMG..."

    # Check for credentials
    if [ -z "${APPLE_ID:-}" ] || [ -z "${APPLE_PASSWORD:-}" ] || [ -z "${APPLE_TEAM_ID:-}" ]; then
        echo "Error: Notarization requires environment variables:"
        echo "  APPLE_ID - Your Apple ID email"
        echo "  APPLE_PASSWORD - App-specific password"
        echo "  APPLE_TEAM_ID - Your Team ID"
        exit 1
    fi

    xcrun notarytool submit "${DMG_PATH}" \
        --apple-id "${APPLE_ID}" \
        --password "${APPLE_PASSWORD}" \
        --team-id "${APPLE_TEAM_ID}" \
        --wait

    # Staple the notarization ticket
    xcrun stapler staple "${DMG_PATH}"

    echo "DMG notarized and stapled successfully"
fi

echo ""
echo "Done! DMG is ready for distribution."
