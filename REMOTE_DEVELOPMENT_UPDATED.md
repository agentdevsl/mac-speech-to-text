# Remote Development Setup: Linux → macOS

**Use Case**: Develop macOS speech-to-text application from Linux dev container with execution on local Mac

**Architecture**: Pure Swift + SwiftUI (requires macOS runtime)

**Strategy**: Use VS Code Remote-SSH to edit code from Linux container, execute/test on Mac

---

## Quick Start (TL;DR)

**In Linux Container**:
```bash
sudo apt-get install -y openssh-client
ssh-keygen -t ed25519 -C "your@email.com"
ssh-copy-id your-username@your-mac-ip
code --install-extension ms-vscode-remote.remote-ssh
```

**On Mac**:
```bash
sudo systemsetup -setremotelogin on
xcode-select --install
git clone <repo-url> ~/Developer/mac-speech-to-text
cd ~/Developer/mac-speech-to-text && swift package resolve
```

**Test**:
```bash
ssh your-username@your-mac-ip "cd ~/Developer/mac-speech-to-text && swift build"
```

---

## Prerequisites

### Mac Requirements

- ✅ Mac with macOS 12.0+ and Apple Silicon (M1/M2/M3/M4)
- ✅ Network connection between container and Mac
- ✅ SSH access to Mac (Remote Login enabled)

### Linux Dev Container Requirements

- ✅ Linux dev container with network access to Mac
- ✅ SSH client installed
- ✅ VS Code with Remote-SSH extension
- ✅ Git installed

---

## Container Prerequisites

**IMPORTANT**: Before starting, ensure your Linux dev container has the required tools installed.

### Required Tools

```bash
# 1. Install SSH client (REQUIRED - not installed by default)
sudo apt-get update && sudo apt-get install -y openssh-client

# 2. Verify SSH installation
ssh -V
# Expected: OpenSSH_9.6p1 or later

# 3. Verify git is installed (usually pre-installed in dev containers)
git --version
# Expected: git version 2.43.0 or later

# 4. Verify VS Code CLI is available
code --version
# Expected: 1.107.1 or later

# 5. Install Remote-SSH extension
code --install-extension ms-vscode-remote.remote-ssh

# 6. Verify extension installed
code --list-extensions | grep remote-ssh
# Expected: ms-vscode-remote.remote-ssh
```

### Network Configuration

Your container must be able to reach your Mac on the local network:

```bash
# Test connectivity (replace with your Mac's hostname or IP)
ping your-mac.local
# OR
ping 192.168.1.X
```

**If ping fails**, check:
- Docker network mode settings (see troubleshooting section)
- Firewall rules on Mac (System Settings → Network → Firewall)
- Local network configuration
- Container and Mac are on the same network

---

## One-Time Setup

### 1. Find Your Mac's Network Address

Before configuring SSH, you need to know how to reach your Mac from the Linux container.

#### Option 1: Using .local Hostname (Recommended)

```bash
# On your Mac, check the hostname
hostname
# Example output: Johns-MacBook-Pro.local

# From Linux container, test if you can resolve it
ping Johns-MacBook-Pro.local
# If this works, use the hostname in SSH config
```

#### Option 2: Using IP Address (More Reliable)

```bash
# On your Mac, find the IP address
# System Settings → Network → [Active Connection] → Details
# Note the "IP Address" value (e.g., 192.168.1.100)

# Or use command line on Mac:
ipconfig getifaddr en0  # For WiFi
ipconfig getifaddr en1  # For Ethernet

# Example output: 192.168.1.100

# From Linux container, verify connectivity
ping 192.168.1.100
```

**Recommendation**: Use IP address if .local hostname doesn't resolve consistently.

---

### 2. Prepare Your Mac

```bash
# SSH into your Mac first (from Linux container)
# Use the hostname or IP you identified above
ssh your-username@your-mac.local
# OR
ssh your-username@192.168.1.100

# Enable Remote Login (if not already enabled)
sudo systemsetup -setremotelogin on

# Verify Remote Login is enabled
sudo systemsetup -getremotelogin
# Should show: Remote Login: On

# Install Xcode Command Line Tools
xcode-select --install

# Verify Xcode installation
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer
# OR: /Library/Developer/CommandLineTools

# Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode from App Store (required for SwiftUI Previews)
# Or download from https://developer.apple.com/xcode/

# Verify Swift installation
swift --version
# Should show: Swift 5.9 or later

# Create Developer directory
mkdir -p ~/Developer
cd ~/Developer

# Clone repository on Mac
# Replace <repository-url> with your actual GitHub/GitLab repository URL
git clone https://github.com/your-username/your-repo.git mac-speech-to-text
# OR with SSH:
# git clone git@github.com:your-username/your-repo.git mac-speech-to-text

cd mac-speech-to-text

# Resolve Swift Package Manager dependencies
swift package resolve

# Verify FluidAudio SDK is resolved
swift package show-dependencies | grep FluidAudio
# Should show: FluidAudio (from 0.9.0)

# Exit SSH session
exit
```

#### Mac Setup Verification Script

Run this script on your Mac to verify everything is configured correctly:

```bash
# Create verification script
cat > ~/verify-mac-setup.sh <<'EOF'
#!/bin/bash
echo "=== Mac Development Environment Verification ==="

# Check Remote Login
echo -n "Remote Login: "
sudo systemsetup -getremotelogin | grep -q "On" && echo "✅ Enabled" || echo "❌ Disabled"

# Check Xcode
echo -n "Xcode Path: "
if xcode-select -p &>/dev/null; then
  echo "✅ $(xcode-select -p)"
else
  echo "❌ Not found"
fi

# Check Swift version
echo -n "Swift: "
if swift --version &>/dev/null; then
  swift --version | head -1
  echo "✅"
else
  echo "❌ Not found"
fi

# Check if project directory exists
echo -n "Project Directory: "
if [ -d ~/Developer/mac-speech-to-text ]; then
  echo "✅ Found at ~/Developer/mac-speech-to-text"
else
  echo "❌ Not found"
  exit 1
fi

# Check Swift Package dependencies
cd ~/Developer/mac-speech-to-text
echo -n "Swift Dependencies: "
if swift package resolve &>/dev/null; then
  echo "✅ Resolved"
else
  echo "❌ Failed"
fi

# Check for FluidAudio
echo -n "FluidAudio SDK: "
if swift package show-dependencies | grep -q FluidAudio; then
  echo "✅ Found"
else
  echo "❌ Not found"
fi

echo ""
echo "=== Verification Complete ==="
EOF

chmod +x ~/verify-mac-setup.sh
./verify-mac-setup.sh
```

---

### 3. Configure SSH from Linux Container

```bash
# In your Linux dev container

# Create SSH directory with proper permissions
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Generate SSH key pair (ed25519 is recommended over RSA)
ssh-keygen -t ed25519 -C "your@email.com" -f ~/.ssh/id_ed25519

# Press Enter to accept default location
# Enter a passphrase (recommended) or leave empty

# Verify key was created
ls -lh ~/.ssh/id_ed25519*
# Should show: id_ed25519 (private) and id_ed25519.pub (public)

# View your public key (you'll copy this to Mac)
cat ~/.ssh/id_ed25519.pub
```

#### Copy SSH Key to Mac

```bash
# Option 1: Using ssh-copy-id (easiest)
ssh-copy-id -i ~/.ssh/id_ed25519.pub your-username@your-mac.local
# OR with IP address:
ssh-copy-id -i ~/.ssh/id_ed25519.pub your-username@192.168.1.100

# Enter your Mac password when prompted
# On first connection, type 'yes' to accept the host key

# Option 2: Manual copy (if ssh-copy-id fails)
# On Mac, add your public key to authorized_keys:
cat ~/.ssh/id_ed25519.pub | ssh your-username@your-mac.local 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

#### Create SSH Config

```bash
# Create SSH config for easy connection
cat > ~/.ssh/config <<'EOF'
Host macdev
    HostName your-mac.local  # or use IP: 192.168.1.100
    User your-username
    IdentityFile ~/.ssh/id_ed25519
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
EOF

# Set proper permissions
chmod 600 ~/.ssh/config

# Test SSH connection (should work without password)
ssh macdev "echo 'Connection successful!'"
# Expected: Connection successful!

# If you see "Connection successful!", your SSH setup is complete! ✅
```

**Note on First Connection**: You'll see a message like:
```
The authenticity of host 'your-mac.local (192.168.1.100)' can't be established.
ED25519 key fingerprint is SHA256:...
Are you sure you want to continue connecting (yes/no/[fingerprint])?
```
Type `yes` and press Enter to continue.

---

### 4. Install VS Code Remote-SSH Extension (Linux Container)

```bash
# Install Remote-SSH extension
code --install-extension ms-vscode-remote.remote-ssh

# Verify installation
code --list-extensions | grep remote-ssh
# Expected: ms-vscode-remote.remote-ssh

# Test VS Code Remote connection
code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text

# VS Code should open connected to your Mac
# Check the bottom-left corner - should show "SSH: macdev"
```

---

## Generate Xcode Project (Optional)

Modern Xcode can work directly with `Package.swift` files, but you can generate a `.xcodeproj` if needed:

### Option 1: Open Package.swift Directly (Recommended)

```bash
# SSH to Mac
ssh macdev

cd ~/Developer/mac-speech-to-text

# Open Swift Package in Xcode (no .xcodeproj needed)
open Package.swift

# Xcode will automatically load the Swift Package
# You should see "SpeechToText" in Xcode's navigator
```

### Option 2: Generate .xcodeproj File

```bash
# SSH to Mac
ssh macdev

cd ~/Developer/mac-speech-to-text

# Generate Xcode project from Package.swift
swift package generate-xcodeproj

# This creates SpeechToText.xcodeproj
# Now you can open it:
open SpeechToText.xcodeproj
```

**Recommendation**: Use Option 1 (open Package.swift directly). Modern Xcode has excellent Swift Package Manager integration.

---

## Development Workflows

### Workflow A: VS Code Remote-SSH ⭐ (Recommended)

**Edit code in VS Code (Linux), execute on Mac**

1. **Connect to Mac**:
   ```bash
   # In VS Code (Linux container)
   # Cmd+Shift+P → "Remote-SSH: Connect to Host"
   # Select: macdev

   # Or use CLI:
   code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text
   ```

2. **Open Project**:
   ```
   File → Open Folder → ~/Developer/mac-speech-to-text
   ```

3. **Develop**:
   - Edit Swift files in VS Code
   - Code executes on Mac in background
   - Use integrated terminal (runs on Mac)

4. **Build & Test**:
   ```bash
   # In VS Code terminal (connected to Mac)
   swift build

   # Run tests
   swift test

   # Build with verbose output
   swift build --verbose

   # Or use Xcode build
   xcodebuild -scheme SpeechToText build
   ```

5. **Run App**:
   ```bash
   # Open in Xcode for GUI development
   open Package.swift
   # OR if you generated .xcodeproj:
   # open SpeechToText.xcodeproj

   # Or run from command line (limited for GUI apps)
   swift run
   ```

**Pros**:
- ✅ Edit in familiar VS Code environment
- ✅ Execute on native macOS
- ✅ Git operations work normally
- ✅ Can use Mac terminal for macOS-specific commands
- ✅ Real-time code sync

**Cons**:
- ❌ No SwiftUI Previews in VS Code (need Xcode)
- ❌ Requires network connection

---

### Workflow B: SSH + Xcode (Hybrid)

**Plan in Linux, code in Xcode on Mac**

1. **Planning/Docs in Linux Container**:
   ```bash
   # Edit specs, docs, architecture in Linux
   vim specs/001-local-speech-to-text/spec.md

   # Commit and push
   git add .
   git commit -m "Update specs"
   git push
   ```

2. **Pull Changes on Mac**:
   ```bash
   # SSH to Mac
   ssh macdev

   cd ~/Developer/mac-speech-to-text
   git pull

   # Open in Xcode
   open Package.swift
   ```

3. **Develop in Xcode**:
   - Use SwiftUI Previews for rapid UI iteration
   - Write Swift code with autocomplete
   - Run tests with Cmd+U
   - Use Instruments for profiling

4. **Commit from Mac**:
   ```bash
   git add .
   git commit -m "feat: implement RecordingModal"
   git push
   ```

**Pros**:
- ✅ Full Xcode features (Previews, Interface Builder)
- ✅ Best Swift development experience
- ✅ Clear separation: planning (Linux) vs coding (Mac)

**Cons**:
- ❌ Context switching between environments
- ❌ Need to sync via git

---

### Workflow C: Terminal-Only via SSH

**Minimal setup, command-line only**

```bash
# From Linux container, SSH to Mac
ssh macdev

# Navigate to project
cd ~/Developer/mac-speech-to-text

# Edit with vim/nano
vim Sources/Views/RecordingModal.swift

# Build
swift build

# Run tests
swift test

# Open in Xcode when needed
open Package.swift
```

**Pros**:
- ✅ Simplest setup
- ✅ Works over slow connections

**Cons**:
- ❌ No code completion (unless using vim plugins)
- ❌ No SwiftUI Previews
- ❌ Manual file navigation

---

## Recommended Setup: VS Code Remote-SSH + Xcode

**Best of both worlds**:

### For Rapid Development (VS Code Remote)
```bash
# Connect from Linux container
code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text

# Edit Swift files, run builds
swift build
swift test
```

### For UI Development (Xcode)
```bash
# SSH to Mac
ssh macdev

# Open Xcode
open ~/Developer/mac-speech-to-text/Package.swift

# Use SwiftUI Previews for UI iteration
# Cmd+Option+P to toggle Preview
```

### For Planning/Docs (Linux Container)
```bash
# Stay in Linux container
vim specs/001-local-speech-to-text/plan.md
git commit -m "Update plan"
git push
```

---

## Testing Strategy

### Unit Tests (Run Remotely)

```bash
# From Linux container via SSH
ssh macdev "cd ~/Developer/mac-speech-to-text && swift test"

# Or in VS Code Remote terminal
swift test --parallel

# With coverage
swift test --enable-code-coverage

# Run specific test
swift test --filter RecordingSessionTests
```

### UI Tests (Require Xcode)

```bash
# SSH to Mac
ssh macdev

# Open Xcode
open ~/Developer/mac-speech-to-text/Package.swift

# Run UI tests: Cmd+U
# Or command line:
xcodebuild test \
  -scheme SpeechToText \
  -destination 'platform=macOS,arch=arm64'
```

### SwiftUI Previews (Xcode Only)

**Cannot run in VS Code - must use Xcode**

```bash
# SSH to Mac
ssh macdev
open ~/Developer/mac-speech-to-text/Package.swift

# Open any SwiftUI view file
# Click "Resume" in Preview pane (right side)
# Cmd+Option+P to toggle Preview
```

---

## Performance Considerations

### Network Latency

- **Local network**: <10ms latency (excellent)
- **Same WiFi**: ~20-50ms (good)
- **Remote network**: >100ms (usable, but slow)

**Tip**: Use wired Ethernet for best performance

### File Sync

VS Code Remote-SSH keeps files in sync automatically. No manual copying needed.

### Build Speed

Builds run on Mac (native Apple Silicon), so performance is optimal.

---

## Troubleshooting

### Issue: Cannot connect via SSH

```bash
# From Linux container, test basic connectivity
ping your-mac.local
# If fails, use IP address instead:
ping 192.168.1.100

# Test SSH with verbose output
ssh -v your-username@your-mac.local
# Check verbose output for errors

# On Mac, verify Remote Login is enabled
sudo systemsetup -getremotelogin
# Should show: Remote Login: On

# Check if SSH service is running on Mac
sudo launchctl list | grep ssh
# Should show: com.openssh.sshd
```

### Issue: SSH connection drops

```bash
# Add keepalive to ~/.ssh/config (already included in setup above)
Host macdev
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes

# If still dropping, increase interval:
    ServerAliveInterval 30
```

### Issue: "Permission denied (publickey)"

```bash
# Verify your SSH key is loaded
ssh-add -l
# If empty, add your key:
ssh-add ~/.ssh/id_ed25519

# Verify your public key is on Mac
ssh macdev "cat ~/.ssh/authorized_keys"
# Should contain your public key from ~/.ssh/id_ed25519.pub

# Test connection with identity file explicitly
ssh -i ~/.ssh/id_ed25519 your-username@your-mac.local

# Check permissions on Mac
ssh macdev "ls -la ~/.ssh/"
# .ssh directory should be 700
# authorized_keys should be 600
```

### Issue: Cannot resolve "your-mac.local"

```bash
# From Linux container, try to find your Mac's IP

# Option 1: Check Mac's IP manually
# On Mac: System Settings → Network → [Your Connection] → Details
# Look for "IP Address: 192.168.x.x"

# Option 2: Use IP address directly in SSH config
# Edit ~/.ssh/config and change:
Host macdev
    HostName 192.168.1.100  # Use actual IP instead of .local
    User your-username
    ...

# Test connection
ssh macdev "echo 'Success'"
```

### Issue: Can't find Xcode

```bash
# On Mac via SSH
sudo xcode-select --switch /Applications/Xcode.app
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer

# If Xcode is not installed
xcode-select --install
```

### Issue: Swift Package Manager fails

```bash
# On Mac via SSH
cd ~/Developer/mac-speech-to-text

# Reset package cache
swift package reset

# Re-resolve dependencies
swift package resolve

# Clean build
swift package clean
swift build

# If FluidAudio fails to resolve, check network
curl -I https://github.com/FluidInference/FluidAudio.git
```

### Issue: VS Code Remote can't find Swift

```bash
# In VS Code Remote terminal (on Mac)
which swift
# Should show: /usr/bin/swift

# If not found, check Xcode path
xcode-select -p

# Add to PATH in your shell profile
echo 'export PATH="/usr/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

### Issue: Docker network blocking Mac access

If using Docker Desktop, ensure your container can access the host network:

#### Option 1: Bridge Mode with Port Forwarding (All platforms)
```bash
# From Linux container
ping <mac-ip-address>

# If ping fails, check:
# 1. Mac and container are on same local network
# 2. No firewall rules blocking SSH port 22
# 3. Docker network settings allow local network access
```

#### Option 2: Docker Desktop Settings (macOS/Windows)
```
Settings → Resources → Network
- Enable "Use kernel networking for UDP"
```

#### Option 3: Verify Mac firewall settings
```bash
# On Mac
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate
# If enabled, add SSH to allowed apps:
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/sbin/sshd
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblockapp /usr/sbin/sshd
```

---

## Git Workflow

### Strategy 1: Commit from Mac

```bash
# Develop on Mac (via SSH or Xcode)
# Commit from Mac
git add .
git commit -m "feat: add feature"
git push

# Pull in Linux container for docs/planning
git pull
```

### Strategy 2: Commit from Both

```bash
# Set up consistent Git identity
# On Mac:
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# In Linux container (same identity):
git config --global user.name "Your Name"
git config --global user.email "your@email.com"

# Commit from either environment
# Git will track changes properly
```

---

## VS Code Extensions (Remote)

When connected to Mac via Remote-SSH, install these extensions **on the remote (Mac)**:

- **Swift Language Support**: `sswg.swift-lang`
- **Swift Format**: `vknabel.swiftformat`
- **GitLens**: `eamodio.gitlens`

```bash
# In VS Code (connected to Mac)
# Extensions → Install on SSH: macdev
# Or via CLI:
code --remote ssh-remote+macdev --install-extension sswg.swift-lang
code --remote ssh-remote+macdev --install-extension vknabel.swiftformat
code --remote ssh-remote+macdev --install-extension eamodio.gitlens
```

---

## Comparison: Remote SSH vs Local Xcode

| Feature | VS Code Remote-SSH | Xcode |
|---------|-------------------|-------|
| Edit Swift files | ✅ Good | ✅ Excellent |
| Code completion | ✅ Good (LSP) | ✅ Excellent |
| SwiftUI Previews | ❌ Not available | ✅ Yes |
| Debugging | ✅ lldb (CLI) | ✅ Visual debugger |
| Git integration | ✅ Excellent | ✅ Good |
| Multi-file refactor | ✅ Good | ✅ Excellent |
| Build speed | ✅ Native | ✅ Native |
| Learning curve | ✅ Familiar (VS Code) | ⚠️ Learning needed |

**Recommendation**: Use both
- **VS Code Remote**: Day-to-day coding, tests, services
- **Xcode**: UI development with SwiftUI Previews

---

## Complete Setup Checklist

### ✅ Linux Dev Container Setup

- [ ] **Install SSH client**: `sudo apt-get update && sudo apt-get install -y openssh-client`
- [ ] **Verify SSH**: `ssh -V` (should show OpenSSH 9.6+)
- [ ] **Create SSH directory**: `mkdir -p ~/.ssh && chmod 700 ~/.ssh`
- [ ] **Generate SSH key**: `ssh-keygen -t ed25519 -C "your@email.com"`
- [ ] **Verify git**: `git --version` (should show git 2.43+)
- [ ] **Verify VS Code CLI**: `code --version`
- [ ] **Install Remote-SSH extension**: `code --install-extension ms-vscode-remote.remote-ssh`
- [ ] **Find Mac IP/hostname**: `ping your-mac.local` OR note IP address

### ✅ macOS Setup

- [ ] **Find Mac IP**: System Settings → Network → Details (note IP address)
- [ ] **Enable Remote Login**: `sudo systemsetup -setremotelogin on`
- [ ] **Verify Remote Login**: `sudo systemsetup -getremotelogin` (should show "On")
- [ ] **Install Xcode Command Line Tools**: `xcode-select --install`
- [ ] **Verify Xcode path**: `xcode-select -p` (should show /Applications/Xcode.app/...)
- [ ] **Verify Swift**: `swift --version` (should show Swift 5.9+)
- [ ] **Install Homebrew** (optional): See https://brew.sh
- [ ] **Create project directory**: `mkdir -p ~/Developer`
- [ ] **Clone repository**: `cd ~/Developer && git clone <repo-url> mac-speech-to-text`
- [ ] **Resolve dependencies**: `cd mac-speech-to-text && swift package resolve`
- [ ] **Verify FluidAudio SDK**: `swift package show-dependencies | grep FluidAudio`
- [ ] **Run verification script**: Create and run ~/verify-mac-setup.sh (see above)

### ✅ SSH Connection Setup

- [ ] **Copy SSH key to Mac**: `ssh-copy-id your-username@your-mac.local` (or use IP)
- [ ] **Accept host key**: Type 'yes' on first connection
- [ ] **Create SSH config**: Add macdev host configuration to `~/.ssh/config`
- [ ] **Test connection**: `ssh macdev "echo 'Success'"` (should print "Success")
- [ ] **Test git over SSH**: `ssh macdev "cd ~/Developer/mac-speech-to-text && git status"`

### ✅ Final Verification

- [ ] **Test Swift build remotely**: `ssh macdev "cd ~/Developer/mac-speech-to-text && swift build"`
- [ ] **Test Swift test remotely**: `ssh macdev "cd ~/Developer/mac-speech-to-text && swift test"`
- [ ] **Test VS Code Remote**: `code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text`
- [ ] **Verify VS Code shows "SSH: macdev"** in bottom-left corner
- [ ] **Test Xcode**: `ssh macdev "open ~/Developer/mac-speech-to-text/Package.swift"`

---

## Next Steps

1. ✅ Set up SSH connection to Mac (follow checklist above)
2. ✅ Install VS Code Remote-SSH extension
3. ✅ Clone repository on Mac
4. ✅ Connect via Remote-SSH and verify
5. ⏭️ Begin implementation with `/speckit.implement`

---

## Quick Reference Commands

```bash
# === Linux Container → Mac Commands ===

# Connect to Mac via SSH
ssh macdev

# Connect via VS Code Remote-SSH
code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text

# Run tests remotely
ssh macdev "cd ~/Developer/mac-speech-to-text && swift test"

# Run build remotely
ssh macdev "cd ~/Developer/mac-speech-to-text && swift build"

# Open Xcode remotely
ssh macdev "open ~/Developer/mac-speech-to-text/Package.swift"

# Check Mac system info
ssh macdev "sw_vers && uname -m"

# === Troubleshooting Commands ===

# Test SSH connectivity
ssh -v macdev

# Check SSH config
ssh -G macdev

# View SSH logs
ssh -vvv macdev

# Test network to Mac
ping your-mac.local

# Check SSH keys
ssh-add -l

# === Git Commands (from either environment) ===

# Check status
git status

# Commit and push
git add .
git commit -m "feat: add feature"
git push

# Pull latest changes
git pull
```

---

**Remote Development Ready!** 🚀

You can now develop Pure Swift + SwiftUI applications from your Linux dev container with execution on your Mac.

**Key Differences from Original**:
- ✅ Added SSH client installation requirement
- ✅ Added container prerequisites section
- ✅ Added Mac IP address discovery steps
- ✅ Fixed .xcodeproj references (use Package.swift instead)
- ✅ Added verification scripts and checklists
- ✅ Expanded troubleshooting with network issues
- ✅ Added first-connection SSH warning
- ✅ Added complete setup checklist with checkboxes
- ✅ Added Quick Start TL;DR section
