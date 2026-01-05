#!/bin/bash
# build-sherpa-onnx.sh
# Builds sherpa-onnx xcframework for macOS from source
#
# Source: https://github.com/k2-fsa/sherpa-onnx
# Documentation: https://k2-fsa.github.io/sherpa/onnx/index.html
#
# Requirements:
# - Xcode Command Line Tools (xcode-select --install)
# - CMake (brew install cmake)
# - Git

set -e

# Configuration
SHERPA_REPO="https://github.com/k2-fsa/sherpa-onnx.git"
SHERPA_BRANCH="master"  # or specific tag like "v1.12.20"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
VENDOR_DIR="${PROJECT_ROOT}/Vendor"
SHERPA_DIR="${VENDOR_DIR}/sherpa-onnx"
FRAMEWORKS_DIR="${PROJECT_ROOT}/Frameworks"

echo "=== Sherpa-ONNX xcframework Builder ==="
echo ""
echo "This script will:"
echo "1. Clone sherpa-onnx repository"
echo "2. Build xcframework for macOS (arm64 + x86_64)"
echo "3. Copy to project Frameworks directory"
echo ""

# Check dependencies
echo "Checking dependencies..."

if ! command -v cmake &> /dev/null; then
    echo "Error: cmake not found. Install with: brew install cmake"
    exit 1
fi

if ! command -v git &> /dev/null; then
    echo "Error: git not found. Install Xcode Command Line Tools."
    exit 1
fi

if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Install Xcode Command Line Tools."
    exit 1
fi

echo "All dependencies found."
echo ""

# Create directories
mkdir -p "${VENDOR_DIR}"
mkdir -p "${FRAMEWORKS_DIR}"

# Clone or update sherpa-onnx
if [ -d "${SHERPA_DIR}" ]; then
    echo "sherpa-onnx directory exists. Updating..."
    cd "${SHERPA_DIR}"
    git fetch origin
    git checkout "${SHERPA_BRANCH}"
    git pull origin "${SHERPA_BRANCH}" || true
else
    echo "Cloning sherpa-onnx..."
    git clone --depth 1 --branch "${SHERPA_BRANCH}" "${SHERPA_REPO}" "${SHERPA_DIR}"
fi

cd "${SHERPA_DIR}"
echo ""
echo "sherpa-onnx version: $(git describe --tags --always)"
echo ""

# Check if xcframework already exists
XCFRAMEWORK_PATH="${SHERPA_DIR}/build-swift-macos/sherpa-onnx.xcframework"
if [ -d "${XCFRAMEWORK_PATH}" ]; then
    echo "xcframework already built at: ${XCFRAMEWORK_PATH}"
    read -p "Rebuild? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping build. Copying existing xcframework..."
        cp -R "${XCFRAMEWORK_PATH}" "${FRAMEWORKS_DIR}/"
        echo "Done! xcframework copied to: ${FRAMEWORKS_DIR}/sherpa-onnx.xcframework"
        exit 0
    fi
    rm -rf "${SHERPA_DIR}/build-swift-macos"
fi

# Build xcframework
echo "Building xcframework for macOS..."
echo "This may take several minutes..."
echo ""

# Build for arm64 only (avoids Fortran universal build issues on Apple Silicon)
# If you need x86_64, install a universal Fortran compiler or build separately
BUILD_DIR="build-swift-macos"
INSTALL_DIR="${BUILD_DIR}/install"

rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

echo "Configuring CMake..."
cmake \
    -DSHERPA_ONNX_ENABLE_BINARY=OFF \
    -DSHERPA_ONNX_BUILD_C_API_EXAMPLES=OFF \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_INSTALL_PREFIX=./install \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=OFF \
    -DSHERPA_ONNX_ENABLE_PYTHON=OFF \
    -DSHERPA_ONNX_ENABLE_TESTS=OFF \
    -DSHERPA_ONNX_ENABLE_CHECK=OFF \
    -DSHERPA_ONNX_ENABLE_PORTAUDIO=OFF \
    -DSHERPA_ONNX_ENABLE_JNI=OFF \
    -DSHERPA_ONNX_ENABLE_C_API=ON \
    -DSHERPA_ONNX_ENABLE_WEBSOCKET=OFF \
    -DSHERPA_ONNX_ENABLE_TTS=OFF \
    -DSHERPA_ONNX_ENABLE_SPEAKER_DIARIZATION=OFF \
    -DEIGEN_BUILD_BLAS=OFF \
    -DEIGEN_BUILD_LAPACK=OFF \
    ../

echo "Building..."
make VERBOSE=1 -j$(sysctl -n hw.ncpu)

echo "Installing..."
make install

# Create combined static library
echo "Creating combined static library..."
cd install/lib
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
    libespeak-ng.a 2>/dev/null || \
libtool -static -o libsherpa-onnx-combined.a \
    libsherpa-onnx-c-api.a \
    libsherpa-onnx-core.a \
    libkaldi-native-fbank-core.a \
    libsherpa-onnx-kaldifst-core.a \
    libkaldi-decoder-core.a \
    libssentencepiece_core.a \
    libonnxruntime.a \
    libucd.a 2>/dev/null || \
libtool -static -o libsherpa-onnx-combined.a *.a

cd ../..

# Create xcframework
echo "Creating xcframework..."
FRAMEWORK_NAME="sherpa_onnx"
FRAMEWORK_DIR="${FRAMEWORK_NAME}.framework"
mkdir -p "${FRAMEWORK_DIR}/Headers"
mkdir -p "${FRAMEWORK_DIR}/Modules"

# Copy headers
cp install/include/sherpa-onnx/c-api/*.h "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true
cp ../sherpa-onnx/c-api/c-api.h "${FRAMEWORK_DIR}/Headers/" 2>/dev/null || true

# Copy library
cp install/lib/libsherpa-onnx-combined.a "${FRAMEWORK_DIR}/${FRAMEWORK_NAME}"

# Create module map
cat > "${FRAMEWORK_DIR}/Modules/module.modulemap" << 'MODULEMAP'
framework module sherpa_onnx {
    umbrella header "c-api.h"
    export *
    module * { export * }
}
MODULEMAP

# Create Info.plist
cat > "${FRAMEWORK_DIR}/Info.plist" << 'PLIST'
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
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>MinimumOSVersion</key>
    <string>14.0</string>
</dict>
</plist>
PLIST

# Create xcframework
xcodebuild -create-xcframework \
    -framework "${FRAMEWORK_DIR}" \
    -output "sherpa-onnx.xcframework"

cd ..
XCFRAMEWORK_PATH="${SHERPA_DIR}/${BUILD_DIR}/sherpa-onnx.xcframework"

# Verify build
if [ ! -d "${XCFRAMEWORK_PATH}" ]; then
    echo "Error: xcframework not created at expected path"
    echo "Expected: ${XCFRAMEWORK_PATH}"
    exit 1
fi

# Copy to project
echo ""
echo "Copying xcframework to project..."
cp -R "${XCFRAMEWORK_PATH}" "${FRAMEWORKS_DIR}/"

# Also copy Swift API files if they exist
SWIFT_API_DIR="${SHERPA_DIR}/swift-api-examples"
if [ -d "${SWIFT_API_DIR}" ]; then
    echo "Copying Swift API examples for reference..."
    mkdir -p "${PROJECT_ROOT}/Resources/sherpa-onnx-swift-api"
    cp -R "${SWIFT_API_DIR}"/*.swift "${PROJECT_ROOT}/Resources/sherpa-onnx-swift-api/" 2>/dev/null || true
fi

# List contents
echo ""
echo "=== Build Complete ==="
echo ""
echo "xcframework installed to: ${FRAMEWORKS_DIR}/sherpa-onnx.xcframework"
ls -la "${FRAMEWORKS_DIR}/sherpa-onnx.xcframework/"
echo ""

# Get size
FRAMEWORK_SIZE=$(du -sh "${FRAMEWORKS_DIR}/sherpa-onnx.xcframework" | cut -f1)
echo "Framework size: ${FRAMEWORK_SIZE}"
echo ""

echo "Next steps:"
echo "1. Add sherpa-onnx.xcframework to Xcode project"
echo "2. Link framework in Build Phases"
echo "3. Update WakeWordService to use sherpa-onnx APIs"
echo ""
echo "For Swift API usage, see:"
echo "  ${PROJECT_ROOT}/Resources/sherpa-onnx-swift-api/"
echo "  https://k2-fsa.github.io/sherpa/onnx/kws/index.html"
