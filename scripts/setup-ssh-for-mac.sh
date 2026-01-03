#!/bin/bash
# SSH Setup Helper for macOS Remote Development
# This script helps configure SSH from Linux container to Mac

set -e

echo "=== SSH Setup for macOS Remote Development ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if SSH client is installed
if ! command -v ssh >/dev/null 2>&1; then
  echo -e "${RED}ERROR: SSH client not installed${NC}"
  echo "Please install it with: sudo apt-get install -y openssh-client"
  exit 1
fi

echo -e "${GREEN}✓${NC} SSH client installed: $(ssh -V 2>&1 | head -1)"
echo ""

# Prompt for Mac details
echo "Please provide your Mac's connection details:"
echo ""

read -p "Mac hostname or IP (e.g., your-mac.local or 192.168.1.100): " MAC_HOST
read -p "Mac username (e.g., john): " MAC_USER
read -p "SSH alias name (default: macdev): " MAC_ALIAS
MAC_ALIAS=${MAC_ALIAS:-macdev}

echo ""
echo "Configuration:"
echo "  Hostname: $MAC_HOST"
echo "  Username: $MAC_USER"
echo "  Alias: $MAC_ALIAS"
echo ""

# Test basic connectivity
echo "Testing connectivity to Mac..."
if ping -c 1 -W 2 "$MAC_HOST" >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} Mac is reachable at $MAC_HOST"
else
  echo -e "${YELLOW}⚠${NC} WARNING: Cannot ping $MAC_HOST"
  echo "  This might be normal if ICMP is blocked"
  echo "  We'll continue with SSH setup..."
fi
echo ""

# Create SSH directory
SSH_DIR="$HOME/.ssh"
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  echo -e "${GREEN}✓${NC} Created SSH directory: $SSH_DIR"
else
  echo -e "${GREEN}✓${NC} SSH directory exists: $SSH_DIR"
fi

# Check for existing SSH keys
if [ -f "$SSH_DIR/id_ed25519" ] || [ -f "$SSH_DIR/id_rsa" ]; then
  echo -e "${YELLOW}⚠${NC} SSH key already exists"
  read -p "Generate new SSH key? (y/N): " GENERATE_KEY
  GENERATE_KEY=${GENERATE_KEY:-N}
else
  GENERATE_KEY="y"
fi

# Generate SSH key if needed
if [ "$GENERATE_KEY" = "y" ] || [ "$GENERATE_KEY" = "Y" ]; then
  echo ""
  echo "Generating SSH key (ed25519)..."
  read -p "Enter email for SSH key (e.g., your@email.com): " SSH_EMAIL

  ssh-keygen -t ed25519 -C "$SSH_EMAIL" -f "$SSH_DIR/id_ed25519"

  if [ -f "$SSH_DIR/id_ed25519" ]; then
    echo -e "${GREEN}✓${NC} SSH key generated successfully"
    echo ""
    echo "Public key:"
    cat "$SSH_DIR/id_ed25519.pub"
    echo ""
  else
    echo -e "${RED}✗${NC} Failed to generate SSH key"
    exit 1
  fi
fi

# Create SSH config
echo "Creating SSH config..."
cat > "$SSH_DIR/config" <<EOF
Host $MAC_ALIAS
    HostName $MAC_HOST
    User $MAC_USER
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
EOF

chmod 600 "$SSH_DIR/config"
echo -e "${GREEN}✓${NC} SSH config created at $SSH_DIR/config"
echo ""

# Test SSH config parsing
echo "Testing SSH config..."
if ssh -G "$MAC_ALIAS" >/dev/null 2>&1; then
  echo -e "${GREEN}✓${NC} SSH config is valid"
else
  echo -e "${RED}✗${NC} SSH config has errors"
  exit 1
fi
echo ""

# Prompt to copy key to Mac
echo "=== Copy SSH Key to Mac ==="
echo ""
echo "Next step: Copy your SSH public key to the Mac"
echo ""
echo "Option 1 (Recommended): Use ssh-copy-id"
echo "  Run: ssh-copy-id -i ~/.ssh/id_ed25519.pub $MAC_ALIAS"
echo ""
echo "Option 2: Manual copy"
echo "  1. Copy your public key:"
echo "     cat ~/.ssh/id_ed25519.pub"
echo "  2. SSH to Mac and add it to authorized_keys:"
echo "     ssh $MAC_USER@$MAC_HOST"
echo "     mkdir -p ~/.ssh && chmod 700 ~/.ssh"
echo "     echo '<paste-public-key-here>' >> ~/.ssh/authorized_keys"
echo "     chmod 600 ~/.ssh/authorized_keys"
echo ""

read -p "Would you like to run ssh-copy-id now? (y/N): " RUN_COPY_ID
RUN_COPY_ID=${RUN_COPY_ID:-N}

if [ "$RUN_COPY_ID" = "y" ] || [ "$RUN_COPY_ID" = "Y" ]; then
  echo ""
  echo "Running ssh-copy-id..."
  echo "You'll be prompted for your Mac password."
  echo "On first connection, type 'yes' to accept the host key."
  echo ""

  if ssh-copy-id -i "$SSH_DIR/id_ed25519.pub" "$MAC_ALIAS"; then
    echo -e "${GREEN}✓${NC} SSH key copied successfully"
  else
    echo -e "${RED}✗${NC} Failed to copy SSH key"
    echo "You can try manually or run: ssh-copy-id -i ~/.ssh/id_ed25519.pub $MAC_ALIAS"
  fi
fi

echo ""
echo "=== Testing SSH Connection ==="
echo ""

# Test SSH connection
if ssh -o BatchMode=yes -o ConnectTimeout=5 "$MAC_ALIAS" "echo 'Connection successful!'" 2>/dev/null; then
  echo -e "${GREEN}✓${NC} SSH connection works! You can now connect with: ssh $MAC_ALIAS"
  echo ""

  # Test Swift
  echo "Testing Swift on Mac..."
  if ssh "$MAC_ALIAS" "swift --version" >/dev/null 2>&1; then
    SWIFT_VERSION=$(ssh "$MAC_ALIAS" "swift --version 2>&1 | head -1")
    echo -e "${GREEN}✓${NC} Swift available: $SWIFT_VERSION"
  else
    echo -e "${YELLOW}⚠${NC} Swift not found on Mac"
    echo "  Install Xcode Command Line Tools: xcode-select --install"
  fi

  echo ""
  echo -e "${GREEN}=== SSH Setup Complete! ===${NC}"
  echo ""
  echo "Quick commands:"
  echo "  - Connect to Mac: ssh $MAC_ALIAS"
  echo "  - Run command remotely: ssh $MAC_ALIAS \"<command>\""
  echo "  - VS Code Remote: code --remote ssh-remote+$MAC_ALIAS ~/Developer/mac-speech-to-text"
  echo ""
  echo "See REMOTE_DEVELOPMENT.md for full workflow guide"

else
  echo -e "${YELLOW}⚠${NC} SSH connection not working yet"
  echo ""
  echo "Troubleshooting steps:"
  echo "  1. Ensure Remote Login is enabled on Mac:"
  echo "     sudo systemsetup -setremotelogin on"
  echo ""
  echo "  2. Copy SSH key to Mac:"
  echo "     ssh-copy-id -i ~/.ssh/id_ed25519.pub $MAC_ALIAS"
  echo ""
  echo "  3. Test connection:"
  echo "     ssh $MAC_ALIAS \"echo 'Success'\""
  echo ""
  echo "  4. Check verbose output for errors:"
  echo "     ssh -v $MAC_ALIAS"
  echo ""
fi

echo ""
