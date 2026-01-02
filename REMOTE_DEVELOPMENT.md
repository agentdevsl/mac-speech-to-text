# Remote Development Setup: Linux → macOS

**Use Case**: Develop macOS speech-to-text application from Linux dev container with execution on local Mac

**Architecture**: Pure Swift + SwiftUI (requires macOS runtime)

**Strategy**: Use VS Code Remote-SSH to edit code from Linux container, execute/test on Mac

---

## Prerequisites

- ✅ Mac with macOS 12.0+ and Apple Silicon (M1/M2/M3/M4)
- ✅ Linux dev container (your current environment)
- ✅ Network connection between container and Mac
- ✅ SSH access to Mac

---

## One-Time Setup

### 1. Prepare Your Mac

```bash
# SSH into your Mac first (from Linux container)
ssh your-username@your-mac.local

# Enable Remote Login (if not already enabled)
sudo systemsetup -setremotelogin on

# Install Xcode Command Line Tools
xcode-select --install

# Install Homebrew (if needed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode from App Store (required for SwiftUI Previews)
# Or download from https://developer.apple.com/xcode/

# Verify Swift installation
swift --version
# Should show: Swift 5.9 or later

# Clone repository on Mac
cd ~/Developer  # or your preferred location
git clone <repository-url> mac-speech-to-text
cd mac-speech-to-text

# Resolve Swift Package Manager dependencies
swift package resolve

# Verify FluidAudio SDK
swift package show-dependencies | grep FluidAudio

# Exit SSH session
exit
```

### 2. Configure SSH from Linux Container

```bash
# In your Linux dev container

# Create SSH config for easy connection
mkdir -p ~/.ssh
cat >> ~/.ssh/config <<'EOF'
Host macdev
    HostName your-mac.local  # or use IP: 192.168.1.X
    User your-username
    ForwardAgent yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
EOF

# Test SSH connection
ssh macdev "echo 'Connection successful!'"

# Set up SSH key (if not already)
ssh-copy-id macdev
# Enter your Mac password when prompted
```

### 3. Install VS Code Remote-SSH Extension (Linux Container)

```bash
# If using VS Code in container
# Install Remote-SSH extension:
# Cmd+Shift+X → search "Remote - SSH" → Install

# Or via CLI
code --install-extension ms-vscode-remote.remote-ssh
```

---

## Development Workflows

### Workflow A: VS Code Remote-SSH ⭐ (Recommended)

**Edit code in VS Code (Linux), execute on Mac**

1. **Connect to Mac**:
   ```bash
   # In VS Code (Linux container)
   # Cmd+Shift+P → "Remote-SSH: Connect to Host"
   # Select: macdev
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
   swift test

   # Or use Xcode build
   xcodebuild -scheme SpeechToText build
   ```

5. **Run App**:
   ```bash
   # Open in Xcode for GUI development
   open SpeechToText.xcodeproj

   # Or run from command line (limited)
   swift run
   ```

**Pros**:
- ✅ Edit in familiar VS Code environment
- ✅ Execute on native macOS
- ✅ Git operations work normally
- ✅ Can use Mac terminal for macOS-specific commands

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
   open SpeechToText.xcodeproj
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
open SpeechToText.xcodeproj
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
open ~/Developer/mac-speech-to-text/SpeechToText.xcodeproj

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
```

### UI Tests (Require Xcode)

```bash
# SSH to Mac
ssh macdev

# Open Xcode
open ~/Developer/mac-speech-to-text/SpeechToText.xcodeproj

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
open ~/Developer/mac-speech-to-text/SpeechToText.xcodeproj

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
# From Linux container
ping your-mac.local
# If fails, use IP address instead

# Test SSH
ssh -v your-username@your-mac.local
# Check verbose output for errors

# On Mac, verify Remote Login is enabled
sudo systemsetup -getremotelogin
# Should show: Remote Login: On
```

### Issue: SSH connection drops

```bash
# Add keepalive to ~/.ssh/config
Host macdev
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
```

### Issue: Can't find Xcode

```bash
# On Mac via SSH
sudo xcode-select --switch /Applications/Xcode.app
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer
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
```

### Issue: VS Code Remote can't find Swift

```bash
# In VS Code Remote terminal (on Mac)
which swift
# Should show: /usr/bin/swift

# If not found, add to PATH
echo 'export PATH="/usr/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
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

## Next Steps

1. ✅ Set up SSH connection to Mac
2. ✅ Install VS Code Remote-SSH extension
3. ✅ Clone repository on Mac
4. ✅ Connect via Remote-SSH and verify
5. ⏭️ Begin implementation with `/speckit.implement`

---

## Quick Reference

```bash
# Connect to Mac from Linux container
ssh macdev

# Or use VS Code Remote-SSH
code --remote ssh-remote+macdev ~/Developer/mac-speech-to-text

# Run tests remotely
ssh macdev "cd ~/Developer/mac-speech-to-text && swift test"

# Open Xcode remotely (if X11 forwarding enabled)
ssh -X macdev "open ~/Developer/mac-speech-to-text/SpeechToText.xcodeproj"

# Build remotely
ssh macdev "cd ~/Developer/mac-speech-to-text && swift build"
```

---

**Remote Development Ready!** 🚀

You can now develop Pure Swift + SwiftUI applications from your Linux dev container with execution on your Mac.
