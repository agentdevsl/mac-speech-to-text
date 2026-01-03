#!/bin/bash
# Post-create setup script for Claude Code devcontainer
set -e

echo "=== Post-Create Setup Starting ==="

# 0. Fix permissions on mounted .claude volume
echo "[0/4] Fixing .claude directory permissions..."
CLAUDE_DIR="/home/node/.claude"
if [ -d "$CLAUDE_DIR" ]; then
  # Check if any files are not owned by current user and fix ownership
  # This handles volumes from previous containers with different users
  if [ "$(find "$CLAUDE_DIR" -not -user "$(whoami)" 2>/dev/null | head -1)" ]; then
    echo "      Volume has files with incorrect ownership - fixing with sudo..."
    sudo chown -R node:node "$CLAUDE_DIR"
  fi
  
  # Ensure required files exist with correct permissions
  chmod 700 "$CLAUDE_DIR"
  
  # Create .claude.json if it doesn't exist
  if [ ! -f "$CLAUDE_DIR/.claude.json" ]; then
    echo '{}' > "$CLAUDE_DIR/.claude.json"
  fi
  chmod 600 "$CLAUDE_DIR/.claude.json"
  
  # Create settings.json if it doesn't exist  
  if [ ! -f "$CLAUDE_DIR/settings.json" ]; then
    echo '{"statusLine": "ccstatusline"}' > "$CLAUDE_DIR/settings.json"
  fi
  chmod 600 "$CLAUDE_DIR/settings.json"
  
  echo "      .claude directory permissions fixed"
else
  echo "      Creating .claude directory..."
  mkdir -p "$CLAUDE_DIR"
  chmod 700 "$CLAUDE_DIR"
  echo '{}' > "$CLAUDE_DIR/.claude.json"
  echo '{"statusLine": "ccstatusline"}' > "$CLAUDE_DIR/settings.json"
  chmod 600 "$CLAUDE_DIR/.claude.json" "$CLAUDE_DIR/settings.json"
fi

# 1. Configure Terraform credentials
echo "[1/4] Configuring Terraform credentials..."
mkdir -p ~/.terraform.d
cat > ~/.terraform.d/credentials.tfrc.json << EOF
{
  "credentials": {
    "app.terraform.io": {
      "token": "${TFE_TOKEN}"
    }
  }
}
EOF
echo "      Terraform credentials configured"

# 2. Install and build Claude hooks for Langfuse tracing
echo "[2/4] Setting up Claude hooks..."
if [ -f /workspace/.claude/hooks/package.json ]; then
  cd /workspace/.claude/hooks
  npm install --silent
  npm run build
  echo "      Claude hooks installed and built"

  # Run health check
  if [ -f scripts/health-check.sh ]; then
    echo "      Running hooks health check..."
    bash scripts/health-check.sh || echo "      (Some health checks may require Langfuse credentials)"
  fi
else
  echo "      No hooks found at /workspace/.claude/hooks - skipping"
fi

# 3. Sync project Claude settings to user config
echo "[3/4] Syncing Claude settings..."
if [ -f /workspace/.claude/settings.json ]; then
  # Merge project hooks settings with user settings
  # The volume-mounted /home/node/.claude may already have settings
  if [ -f /home/node/.claude/settings.json ]; then
    echo "      User settings exist - hooks will be loaded from project .claude/settings.json"
  else
    echo "      Creating user settings directory link"
  fi
fi

# 4. Set up SSH directory for remote development
echo "[4/4] Setting up SSH for remote development..."
SSH_DIR="/home/node/.ssh"
if [ ! -d "$SSH_DIR" ]; then
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  echo "      SSH directory created at $SSH_DIR"
else
  chmod 700 "$SSH_DIR"
  echo "      SSH directory already exists - permissions verified"
fi

# Verify SSH client is installed
if command -v ssh >/dev/null 2>&1; then
  SSH_VERSION=$(ssh -V 2>&1 | head -1)
  echo "      SSH client installed: $SSH_VERSION"
else
  echo "      WARNING: SSH client not found (should be in Docker image)"
fi

echo ""
echo "=== Post-Create Setup Complete ==="
echo ""
echo "Claude hooks status:"
echo "  - Langfuse tracing: $([ -f /workspace/.claude/hooks/dist/langfuse-hook.js ] && echo 'Ready' || echo 'Not built')"
echo "  - LANGFUSE_PUBLIC_KEY: $([ -n \"$LANGFUSE_PUBLIC_KEY\" ] && echo 'configured' || echo 'missing')"
echo "  - LANGFUSE_SECRET_KEY: $([ -n \"$LANGFUSE_SECRET_KEY\" ] && echo 'configured' || echo 'missing')"
echo ""
echo "Remote Development:"
echo "  - SSH client: $(command -v ssh >/dev/null 2>&1 && echo 'Ready' || echo 'Not installed')"
echo "  - SSH directory: $([ -d /home/node/.ssh ] && echo 'Created' || echo 'Missing')"
echo ""
echo "Next steps for remote development:"
echo "  1. Generate SSH key: ssh-keygen -t ed25519 -C \"your@email.com\""
echo "  2. Copy key to Mac: ssh-copy-id your-username@your-mac-ip"
echo "  3. See REMOTE_DEVELOPMENT.md for full setup guide"
echo ""
