#!/bin/bash
# setup-sherpa-onnx.sh
# Downloads pre-built sherpa-onnx and creates xcframework for the project
#
# This script is designed for CI environments where we can't build from source.
# It downloads the official pre-built release and packages it as an xcframework.

set -e

# Configuration
SHERPA_VERSION="${SHERPA_VERSION:-v1.12.20}"
SHERPA_RELEASE_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/${SHERPA_VERSION}/sherpa-onnx-${SHERPA_VERSION#v}-osx-universal2-static.tar.bz2"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
FRAMEWORKS_DIR="${PROJECT_ROOT}/Frameworks"
TEMP_DIR="${PROJECT_ROOT}/.sherpa-temp"

echo "=== Sherpa-ONNX XCFramework Setup ==="
echo ""
echo "Version: ${SHERPA_VERSION}"
echo "Frameworks dir: ${FRAMEWORKS_DIR}"
echo ""

# Check if xcframework already exists
if [ -d "${FRAMEWORKS_DIR}/sherpa-onnx.xcframework" ]; then
    echo "✓ sherpa-onnx.xcframework already exists"
    echo "  To rebuild, remove: ${FRAMEWORKS_DIR}/sherpa-onnx.xcframework"
    exit 0
fi

# Create directories
mkdir -p "${FRAMEWORKS_DIR}"
mkdir -p "${TEMP_DIR}"

# Download pre-built release
ARCHIVE_NAME="sherpa-onnx-${SHERPA_VERSION#v}-osx-universal2-static.tar.bz2"
ARCHIVE_PATH="${TEMP_DIR}/${ARCHIVE_NAME}"

if [ ! -f "${ARCHIVE_PATH}" ]; then
    echo "Downloading ${SHERPA_VERSION} pre-built release..."
    curl -sL "${SHERPA_RELEASE_URL}" -o "${ARCHIVE_PATH}"
    echo "✓ Downloaded ${ARCHIVE_NAME}"
else
    echo "✓ Using cached ${ARCHIVE_NAME}"
fi

# Extract
echo "Extracting archive..."
cd "${TEMP_DIR}"
tar -xjf "${ARCHIVE_NAME}"
EXTRACTED_DIR="${TEMP_DIR}/sherpa-onnx-${SHERPA_VERSION#v}-osx-universal2-static"
echo "✓ Extracted to ${EXTRACTED_DIR}"

# Create combined static library
echo "Creating combined static library..."
cd "${EXTRACTED_DIR}/lib"

# Combine all static libraries into one
# Order matters for dependency resolution
libtool -static -o libsherpa-onnx-combined.a \
    libsherpa-onnx-c-api.a \
    libsherpa-onnx-core.a \
    libkaldi-native-fbank-core.a \
    libsherpa-onnx-kaldifst-core.a \
    libkaldi-decoder-core.a \
    libssentencepiece_core.a \
    libonnxruntime.a \
    libucd.a \
    libpiper_phonemize.a \
    libespeak-ng.a \
    libkissfft-float.a \
    libsherpa-onnx-fst.a \
    libsherpa-onnx-fstfar.a 2>/dev/null || \
libtool -static -o libsherpa-onnx-combined.a *.a

echo "✓ Created combined library"

# Create framework structure
echo "Creating framework..."
FRAMEWORK_DIR="${TEMP_DIR}/sherpa_onnx.framework"
rm -rf "${FRAMEWORK_DIR}"
mkdir -p "${FRAMEWORK_DIR}/Headers"
mkdir -p "${FRAMEWORK_DIR}/Modules"

# Copy headers
cp "${EXTRACTED_DIR}/include/sherpa-onnx/c-api/c-api.h" "${FRAMEWORK_DIR}/Headers/"
cp "${EXTRACTED_DIR}/include/sherpa-onnx/c-api/cxx-api.h" "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true

# Copy combined library as framework binary
cp "${EXTRACTED_DIR}/lib/libsherpa-onnx-combined.a" "${FRAMEWORK_DIR}/sherpa_onnx"

# Create module map
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << 'MODULEMAP'
framework module sherpa_onnx {
    umbrella header "c-api.h"
    export *
    module * { export * }
}
MODULEMAP

# Create Info.plist
cat > "${FRAMEWORK_DIR}/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>sherpa_onnx</string>
    <key>CFBundleIdentifier</key>
    <string>org.k2-fsa.sherpa-onnx</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>sherpa_onnx</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${SHERPA_VERSION#v}</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

echo "✓ Created framework structure"

# Create xcframework
# The universal2 build contains both arm64 and x86_64, so we create a single-library xcframework
# macOS runners may be either architecture, so this works for both
echo "Creating xcframework..."
cd "${TEMP_DIR}"

xcodebuild -create-xcframework \
    -framework "${FRAMEWORK_DIR}" \
    -output "sherpa-onnx.xcframework"

echo "✓ Created xcframework"

# Move to project Frameworks directory
mv "${TEMP_DIR}/sherpa-onnx.xcframework" "${FRAMEWORKS_DIR}/"

# Cleanup
echo "Cleaning up..."
rm -rf "${TEMP_DIR}"

echo ""
echo "=== Setup Complete ==="
echo ""
echo "✓ Installed: ${FRAMEWORKS_DIR}/sherpa-onnx.xcframework"
ls -la "${FRAMEWORKS_DIR}/sherpa-onnx.xcframework/"
echo ""

# Get size
FRAMEWORK_SIZE=$(du -sh "${FRAMEWORKS_DIR}/sherpa-onnx.xcframework" | cut -f1)
echo "Framework size: ${FRAMEWORK_SIZE}"
