#!/bin/bash
# =============================================================================
# setup-signing.sh
# =============================================================================
# Creates a self-signed code signing certificate for consistent local builds.
# This allows macOS to recognize the app as the same app across builds,
# preserving permissions (Accessibility, Microphone, etc.).
#
# Usage: ./scripts/setup-signing.sh [options]
#
# Options:
#   --name NAME     Certificate name (default: SpeechToText-Dev)
#   --days DAYS     Validity in days (default: 3650 = 10 years)
#   --help          Show this help message
#
# After running, builds will automatically use this certificate.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Defaults
CERT_NAME="SpeechToText-Dev"
VALIDITY_DAYS=3650

print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_warning() { echo -e "${YELLOW}⚠${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_info() { echo -e "${CYAN}ℹ${NC} $1"; }

show_help() {
    head -20 "$0" | tail -15 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            CERT_NAME="$2"
            shift 2
            ;;
        --days)
            VALIDITY_DAYS="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "\n${BOLD}${CYAN}Setting up code signing for SpeechToText${NC}\n"

# Check if certificate already exists
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    print_success "Certificate '${CERT_NAME}' already exists"

    # Save identity to file
    echo "${CERT_NAME}" > "${PROJECT_ROOT}/.signing-identity"
    print_success "Saved signing identity to .signing-identity"

    echo -e "\n${GREEN}Done!${NC} Your builds will now use this certificate."
    echo "Run: ./scripts/build-app.sh --release --dmg"
    exit 0
fi

print_info "Creating self-signed certificate: ${CERT_NAME}"
print_info "Validity: ${VALIDITY_DAYS} days"

# Create certificate using security command
# This creates a self-signed certificate in the login keychain
cat > /tmp/cert-config.txt << EOF
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
prompt             = no
x509_extensions    = codesign

[ req_distinguished_name ]
CN = ${CERT_NAME}

[ codesign ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

# Generate private key and certificate
openssl req -x509 -newkey rsa:2048 \
    -keyout /tmp/cert-key.pem \
    -out /tmp/cert.pem \
    -days ${VALIDITY_DAYS} \
    -nodes \
    -config /tmp/cert-config.txt 2>/dev/null

# Create PKCS12 file (required for keychain import)
openssl pkcs12 -export \
    -inkey /tmp/cert-key.pem \
    -in /tmp/cert.pem \
    -out /tmp/cert.p12 \
    -passout pass: 2>/dev/null

# Import into keychain
print_info "Importing certificate into login keychain..."
print_warning "You may be prompted for your macOS password"

security import /tmp/cert.p12 \
    -k ~/Library/Keychains/login.keychain-db \
    -P "" \
    -T /usr/bin/codesign \
    -T /usr/bin/security 2>/dev/null || {
    print_error "Failed to import certificate"
    print_info "Try creating manually in Keychain Access:"
    echo "  1. Open Keychain Access"
    echo "  2. Keychain Access > Certificate Assistant > Create a Certificate"
    echo "  3. Name: ${CERT_NAME}"
    echo "  4. Identity Type: Self Signed Root"
    echo "  5. Certificate Type: Code Signing"
    rm -f /tmp/cert-config.txt /tmp/cert-key.pem /tmp/cert.pem /tmp/cert.p12
    exit 1
}

# Trust the certificate for code signing
print_info "Setting certificate trust for code signing..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# Clean up temp files
rm -f /tmp/cert-config.txt /tmp/cert-key.pem /tmp/cert.pem /tmp/cert.p12

# Verify certificate was created
if security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    print_success "Certificate created successfully"

    # Save identity to file
    echo "${CERT_NAME}" > "${PROJECT_ROOT}/.signing-identity"
    print_success "Saved signing identity to .signing-identity"

    # Add to .gitignore if not already there
    if ! grep -q "^\.signing-identity$" "${PROJECT_ROOT}/.gitignore" 2>/dev/null; then
        echo ".signing-identity" >> "${PROJECT_ROOT}/.gitignore"
        print_success "Added .signing-identity to .gitignore"
    fi

    echo -e "\n${GREEN}${BOLD}Setup complete!${NC}"
    echo ""
    echo "Your builds will now be signed with '${CERT_NAME}'."
    echo "This ensures macOS recognizes the app consistently across builds,"
    echo "preserving Accessibility, Microphone, and other permissions."
    echo ""
    echo "Build with: ./scripts/build-app.sh --release --dmg"
else
    print_error "Certificate creation may have failed"
    print_info "Check Keychain Access manually"
    exit 1
fi
