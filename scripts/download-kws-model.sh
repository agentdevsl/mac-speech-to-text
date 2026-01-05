#!/bin/bash
# download-kws-model.sh
# Downloads the sherpa-onnx keyword spotting model for voice trigger feature
#
# Source: https://github.com/k2-fsa/sherpa-onnx/releases/tag/kws-models
# Documentation: https://k2-fsa.github.io/sherpa/onnx/kws/index.html

set -e

# Configuration
MODEL_NAME="sherpa-onnx-kws-zipformer-gigaspeech-3.3M-2024-01-01"
MODEL_URL="https://github.com/k2-fsa/sherpa-onnx/releases/download/kws-models/${MODEL_NAME}.tar.bz2"

# Paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="${PROJECT_ROOT}/Resources"
MODELS_DIR="${RESOURCES_DIR}/Models"
KWS_MODEL_DIR="${MODELS_DIR}/kws"
TEMP_DIR="${PROJECT_ROOT}/.tmp-model-download"

echo "=== Sherpa-ONNX Keyword Spotting Model Downloader ==="
echo ""
echo "Model: ${MODEL_NAME}"
echo "Source: ${MODEL_URL}"
echo ""

# Check if model already exists
if [ -d "${KWS_MODEL_DIR}/${MODEL_NAME}" ]; then
    echo "Model already exists at: ${KWS_MODEL_DIR}/${MODEL_NAME}"
    read -p "Do you want to re-download? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Skipping download."
        exit 0
    fi
    rm -rf "${KWS_MODEL_DIR}/${MODEL_NAME}"
fi

# Create directories
echo "Creating directories..."
mkdir -p "${KWS_MODEL_DIR}"
mkdir -p "${TEMP_DIR}"

# Download model
echo "Downloading model (this may take a moment)..."
TARBALL="${TEMP_DIR}/${MODEL_NAME}.tar.bz2"

if command -v curl &> /dev/null; then
    curl -L --progress-bar -o "${TARBALL}" "${MODEL_URL}"
elif command -v wget &> /dev/null; then
    wget --show-progress -O "${TARBALL}" "${MODEL_URL}"
else
    echo "Error: Neither curl nor wget found. Please install one of them."
    exit 1
fi

# Verify download
if [ ! -f "${TARBALL}" ]; then
    echo "Error: Download failed"
    exit 1
fi

FILE_SIZE=$(stat -f%z "${TARBALL}" 2>/dev/null || stat -c%s "${TARBALL}" 2>/dev/null)
echo "Downloaded: ${FILE_SIZE} bytes"

# Extract model
echo "Extracting model..."
cd "${TEMP_DIR}"
tar xjf "${MODEL_NAME}.tar.bz2"

# Move to final location
echo "Installing model to ${KWS_MODEL_DIR}..."
mv "${MODEL_NAME}" "${KWS_MODEL_DIR}/"

# Clean up
echo "Cleaning up..."
rm -rf "${TEMP_DIR}"

# List model contents
echo ""
echo "=== Model Contents ==="
ls -la "${KWS_MODEL_DIR}/${MODEL_NAME}/"

# Show important files
echo ""
echo "=== Key Files ==="
echo "Encoder: ${KWS_MODEL_DIR}/${MODEL_NAME}/encoder-epoch-12-avg-2-chunk-16-left-64.onnx"
echo "Decoder: ${KWS_MODEL_DIR}/${MODEL_NAME}/decoder-epoch-12-avg-2-chunk-16-left-64.onnx"
echo "Joiner:  ${KWS_MODEL_DIR}/${MODEL_NAME}/joiner-epoch-12-avg-2-chunk-16-left-64.onnx"
echo "Tokens:  ${KWS_MODEL_DIR}/${MODEL_NAME}/tokens.txt"

echo ""
echo "=== Download Complete ==="
echo ""
echo "Model installed to: ${KWS_MODEL_DIR}/${MODEL_NAME}"
echo ""
echo "Next steps:"
echo "1. Build sherpa-onnx xcframework (see scripts/build-sherpa-onnx.sh)"
echo "2. Add model files to Xcode project bundle"
echo "3. Configure WakeWordService with model path"
