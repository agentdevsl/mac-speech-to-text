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
#   --verify        Verify existing identity without creating new one
#   --force         Force recreation of certificate even if it exists
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
VERIFY_ONLY=false
FORCE_RECREATE=false

print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_info() { echo -e "${CYAN}[INFO]${NC} $1"; }

# =============================================================================
# T016: Prerequisite check function
# =============================================================================
check_prerequisites() {
    local has_error=false

    print_info "Checking prerequisites..."

    # Check security command
    if ! command -v security &> /dev/null; then
        print_error "security command not found"
        echo "  This is a built-in macOS command. Ensure you're running on macOS."
        has_error=true
    else
        print_success "security command available"
    fi

    # Check codesign command
    if ! command -v codesign &> /dev/null; then
        print_error "codesign command not found"
        echo ""
        echo "  Remediation: Install Xcode Command Line Tools:"
        echo "    xcode-select --install"
        echo ""
        has_error=true
    else
        print_success "codesign command available"
    fi

    # Check openssl command
    if ! command -v openssl &> /dev/null; then
        print_error "openssl command not found"
        echo ""
        echo "  Remediation: OpenSSL should be included with macOS."
        echo "  If missing, install via Homebrew:"
        echo "    brew install openssl"
        echo ""
        has_error=true
    else
        print_success "openssl command available"
    fi

    # Check login keychain exists
    if [ ! -f ~/Library/Keychains/login.keychain-db ]; then
        print_error "Login keychain not found"
        echo ""
        echo "  Remediation: Open Keychain Access to initialize your keychain:"
        echo "    open -a 'Keychain Access'"
        echo ""
        has_error=true
    else
        print_success "Login keychain found"
    fi

    if [ "$has_error" = true ]; then
        echo ""
        print_error "Prerequisites check failed. Please resolve the issues above."
        exit 1
    fi

    print_success "All prerequisites satisfied"
}

# =============================================================================
# T008: Identity validation function
# =============================================================================
validate_identity_in_keychain() {
    local identity_name="$1"

    # Check if the identity exists in the keychain
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "${identity_name}"; then
        return 0
    else
        return 1
    fi
}

# =============================================================================
# T009: Certificate expiration check
# =============================================================================
check_certificate_expiration() {
    local cert_name="$1"

    # Get certificate details using security command
    local cert_info
    cert_info=$(security find-certificate -c "${cert_name}" -p 2>/dev/null || echo "")

    if [ -z "$cert_info" ]; then
        print_warning "Could not retrieve certificate details for expiration check"
        return 1
    fi

    # Parse expiration date using openssl
    local expiry_date
    expiry_date=$(echo "$cert_info" | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2 || echo "")

    if [ -z "$expiry_date" ]; then
        print_warning "Could not determine certificate expiration date"
        return 1
    fi

    # Convert to epoch for comparison
    local expiry_epoch
    local current_epoch

    # macOS date command syntax
    expiry_epoch=$(date -j -f "%b %d %T %Y %Z" "$expiry_date" +%s 2>/dev/null || echo "0")
    current_epoch=$(date +%s)

    if [ "$expiry_epoch" = "0" ]; then
        # Try alternative date format parsing
        print_info "Certificate expiry date: ${expiry_date}"
        return 0
    fi

    # Calculate days until expiration
    local days_remaining=$(( (expiry_epoch - current_epoch) / 86400 ))

    if [ "$days_remaining" -lt 0 ]; then
        print_error "Certificate '${cert_name}' has EXPIRED!"
        echo ""
        echo "  Remediation: Recreate the certificate:"
        echo "    ./scripts/setup-signing.sh --force"
        echo ""
        return 2
    elif [ "$days_remaining" -lt 30 ]; then
        print_warning "Certificate '${cert_name}' expires in ${days_remaining} days"
        echo ""
        echo "  Recommendation: Consider recreating before expiration:"
        echo "    ./scripts/setup-signing.sh --force"
        echo ""
        return 0
    elif [ "$days_remaining" -lt 365 ]; then
        print_info "Certificate expires in ${days_remaining} days"
        return 0
    else
        print_success "Certificate valid for ${days_remaining} days ($(( days_remaining / 365 )) years)"
        return 0
    fi
}

# =============================================================================
# T019: Certificate CN validation
# =============================================================================
validate_certificate_name() {
    local name="$1"

    # Check length (1-64 characters for CN)
    if [ ${#name} -lt 1 ]; then
        print_error "Certificate name cannot be empty"
        return 1
    fi

    if [ ${#name} -gt 64 ]; then
        print_error "Certificate name too long (max 64 characters, got ${#name})"
        echo ""
        echo "  Remediation: Use a shorter certificate name"
        echo ""
        return 1
    fi

    # Check for invalid characters (basic validation)
    if [[ "$name" =~ [/\\:\*\?\"\'<>\|] ]]; then
        print_error "Certificate name contains invalid characters"
        echo ""
        echo "  Invalid characters: / \\ : * ? \" ' < > |"
        echo "  Remediation: Use alphanumeric characters and hyphens only"
        echo ""
        return 1
    fi

    return 0
}

# =============================================================================
# T007: Verify flag implementation
# =============================================================================
verify_existing_identity() {
    echo ""
    echo -e "${BOLD}${CYAN}Verifying Code Signing Identity${NC}"
    echo ""

    # Check .signing-identity file
    local identity_file="${PROJECT_ROOT}/.signing-identity"
    if [ -f "$identity_file" ]; then
        local stored_identity
        stored_identity=$(cat "$identity_file" | tr -d '\n')
        print_success "Found .signing-identity file: ${stored_identity}"

        # Validate in keychain
        if validate_identity_in_keychain "$stored_identity"; then
            print_success "Identity '${stored_identity}' found in keychain"

            # Check expiration
            check_certificate_expiration "$stored_identity"

            # Show signing verification command
            echo ""
            echo "To verify app signing, run:"
            echo "  codesign -dv build/SpeechToText.app 2>&1 | grep Authority"
            echo ""
            return 0
        else
            print_error "Identity '${stored_identity}' NOT found in keychain!"
            echo ""
            echo "  Remediation options:"
            echo "    1. Recreate the certificate:"
            echo "       ./scripts/setup-signing.sh --force"
            echo ""
            echo "    2. Or manually create in Keychain Access:"
            show_keychain_fallback_instructions "$stored_identity"
            echo ""
            return 1
        fi
    else
        print_warning "No .signing-identity file found"
        echo ""
        echo "  Remediation: Run setup to create signing identity:"
        echo "    ./scripts/setup-signing.sh"
        echo ""
        return 1
    fi
}

# =============================================================================
# T010 & T017: Enhanced error messages and Keychain fallback instructions
# =============================================================================
show_keychain_fallback_instructions() {
    local cert_name="${1:-SpeechToText-Dev}"

    echo ""
    echo -e "${BOLD}Manual Certificate Creation (Keychain Access)${NC}"
    echo ""
    echo "If automatic certificate creation fails, create manually:"
    echo ""
    echo "  1. Open Keychain Access:"
    echo "     open -a 'Keychain Access'"
    echo ""
    echo "  2. From menu: Keychain Access > Certificate Assistant > Create a Certificate"
    echo ""
    echo "  3. Fill in the dialog:"
    echo "     - Name: ${cert_name}"
    echo "     - Identity Type: Self Signed Root"
    echo "     - Certificate Type: Code Signing"
    echo ""
    echo "  4. Click 'Create' and grant any permissions requested"
    echo ""
    echo "  5. Create the identity file:"
    echo "     echo '${cert_name}' > ${PROJECT_ROOT}/.signing-identity"
    echo ""
    echo "  6. Verify with:"
    echo "     security find-identity -v -p codesigning | grep '${cert_name}'"
    echo ""
}

show_help() {
    echo ""
    echo "Usage: ./scripts/setup-signing.sh [options]"
    echo ""
    echo "Creates a self-signed code signing certificate for consistent local builds."
    echo "This preserves macOS TCC permissions (Accessibility, Microphone) across rebuilds."
    echo ""
    echo "Options:"
    echo "  --name NAME     Certificate name (default: SpeechToText-Dev)"
    echo "  --days DAYS     Validity in days (default: 3650 = 10 years)"
    echo "  --verify        Verify existing identity without creating new one"
    echo "  --force         Force recreation of certificate even if it exists"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./scripts/setup-signing.sh                    # Create/verify identity"
    echo "  ./scripts/setup-signing.sh --verify           # Check existing identity"
    echo "  ./scripts/setup-signing.sh --force            # Recreate certificate"
    echo "  ./scripts/setup-signing.sh --name MyApp-Dev   # Use custom name"
    echo ""
    exit 0
}

# =============================================================================
# Parse arguments
# =============================================================================
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            if [[ -z "${2:-}" || "${2:-}" == --* ]]; then
                print_error "--name requires a value"
                exit 1
            fi
            CERT_NAME="$2"
            shift 2
            ;;
        --days)
            if [[ -z "${2:-}" || ! "${2:-}" =~ ^[0-9]+$ ]]; then
                print_error "--days requires a positive integer"
                exit 1
            fi
            VALIDITY_DAYS="$2"
            shift 2
            ;;
        --verify)
            VERIFY_ONLY=true
            shift
            ;;
        --force)
            FORCE_RECREATE=true
            shift
            ;;
        --help|-h)
            show_help
            ;;
        *)
            print_error "Unknown option: $1"
            echo ""
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# Main execution
# =============================================================================

echo ""
echo -e "${BOLD}${CYAN}Setting up Code Signing for SpeechToText${NC}"
echo ""

# T016: Check prerequisites first
check_prerequisites

# T019: Validate certificate name
if ! validate_certificate_name "$CERT_NAME"; then
    exit 1
fi

# T007: Handle --verify flag
if [ "$VERIFY_ONLY" = true ]; then
    verify_existing_identity
    exit $?
fi

# Check if certificate already exists (unless --force)
if [ "$FORCE_RECREATE" = false ] && security find-identity -v -p codesigning 2>/dev/null | grep -q "${CERT_NAME}"; then
    print_success "Certificate '${CERT_NAME}' already exists"

    # T009: Check expiration
    check_certificate_expiration "$CERT_NAME"

    # Save identity to file
    echo "${CERT_NAME}" > "${PROJECT_ROOT}/.signing-identity"
    print_success "Saved signing identity to .signing-identity"

    echo ""
    echo -e "${GREEN}Done!${NC} Your builds will now use this certificate."
    echo ""
    echo "Next steps:"
    echo "  ./scripts/build-app.sh --release --dmg"
    echo ""
    exit 0
fi

if [ "$FORCE_RECREATE" = true ]; then
    print_info "Force recreating certificate: ${CERT_NAME}"
fi

print_info "Creating self-signed certificate: ${CERT_NAME}"
print_info "Validity: ${VALIDITY_DAYS} days ($(( VALIDITY_DAYS / 365 )) years)"

# Create secure temporary directory for sensitive files (private keys)
SECURE_TEMP_DIR=$(mktemp -d)
chmod 700 "${SECURE_TEMP_DIR}"
# Ensure cleanup on exit, error, or interrupt
cleanup_temp() {
    rm -rf "${SECURE_TEMP_DIR}" 2>/dev/null || true
}
trap cleanup_temp EXIT INT TERM

# Create certificate using security command
# This creates a self-signed certificate in the login keychain
cat > "${SECURE_TEMP_DIR}/cert-config.txt" << EOF
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

# Generate private key and certificate in secure temp directory
if ! openssl req -x509 -newkey rsa:2048 \
    -keyout "${SECURE_TEMP_DIR}/cert-key.pem" \
    -out "${SECURE_TEMP_DIR}/cert.pem" \
    -days ${VALIDITY_DAYS} \
    -nodes \
    -config "${SECURE_TEMP_DIR}/cert-config.txt" 2>/dev/null; then
    print_error "Failed to generate certificate with OpenSSL"
    echo ""
    echo "  Remediation: Check OpenSSL installation:"
    echo "    openssl version"
    echo ""
    echo "  If OpenSSL is missing, install with Homebrew:"
    echo "    brew install openssl"
    echo ""
    show_keychain_fallback_instructions "$CERT_NAME"
    exit 1
fi

# Create PKCS12 file (required for keychain import)
if ! openssl pkcs12 -export \
    -inkey "${SECURE_TEMP_DIR}/cert-key.pem" \
    -in "${SECURE_TEMP_DIR}/cert.pem" \
    -out "${SECURE_TEMP_DIR}/cert.p12" \
    -passout pass: 2>/dev/null; then
    print_error "Failed to create PKCS12 file"
    echo ""
    show_keychain_fallback_instructions "$CERT_NAME"
    exit 1
fi

# Import into keychain
print_info "Importing certificate into login keychain..."
print_warning "You may be prompted for your macOS password"

if ! security import "${SECURE_TEMP_DIR}/cert.p12" \
    -k ~/Library/Keychains/login.keychain-db \
    -P "" \
    -T /usr/bin/codesign \
    -T /usr/bin/security 2>/dev/null; then
    print_error "Failed to import certificate into keychain"
    echo ""
    echo "  Common causes:"
    echo "    - Keychain is locked"
    echo "    - Insufficient permissions"
    echo "    - Keychain password mismatch"
    echo ""
    echo "  Remediation: Try unlocking your keychain first:"
    echo "    security unlock-keychain ~/Library/Keychains/login.keychain-db"
    echo ""
    show_keychain_fallback_instructions "$CERT_NAME"
    exit 1
fi

# Trust the certificate for code signing
print_info "Setting certificate trust for code signing..."
security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "" ~/Library/Keychains/login.keychain-db 2>/dev/null || true

# Temp files are cleaned up automatically via trap

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

    echo ""
    echo -e "${GREEN}${BOLD}Setup complete!${NC}"
    echo ""
    echo "Your builds will now be signed with '${CERT_NAME}'."
    echo "This ensures macOS recognizes the app consistently across builds,"
    echo "preserving Accessibility, Microphone, and other permissions."
    echo ""
    echo "Next steps:"
    echo "  1. Build the app:"
    echo "     ./scripts/build-app.sh --release --dmg"
    echo ""
    echo "  2. Grant permissions on first launch"
    echo ""
    echo "  3. Verify persistence by rebuilding - permissions should remain"
    echo ""
else
    print_error "Certificate creation may have failed"
    echo ""
    echo "  The certificate was not found in the keychain after creation."
    echo ""
    show_keychain_fallback_instructions "$CERT_NAME"
    exit 1
fi
