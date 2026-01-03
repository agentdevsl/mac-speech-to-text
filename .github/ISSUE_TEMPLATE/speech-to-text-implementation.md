# 🎙️ macOS Local Speech-to-Text Application

## Vision

Create a beautiful, privacy-focused macOS speech-to-text application that feels like a premium native app. Think Superwhisper, but with local AI processing for complete privacy. The app should be invisible until needed, then appear with an elegant interface that delights users.

---

## 🎯 Design Philosophy

Following **[HashiCorp's Tao](https://www.hashicorp.com/en/tao-of-hashicorp)**:

1. **Workflows, Not Technologies** - Focus on "speak → text appears" workflow
2. **Simple, Modular, Composable** - Clean architecture with swappable components
3. **Pragmatism** - Use the best tools for Apple Silicon
4. **Codification** - Version-controlled configuration
5. **Technology-Agnostic** - Abstract ML models, audio backends

### Aesthetic Direction: **"Warm Minimalism"**

- **Tone**: Refined, approachable, sophisticated
- **Visual**: Spacious layouts, frosted glass, subtle shadows
- **Typography**: SF Pro (UI) + Berkeley Mono (technical elements)
- **Color**: Warm palette - amber accents (#F59E0B), soft grays, organic warmth
- **Motion**: Gentle spring animations, physics-based interactions
- **Key Feature**: "Invisible until needed" - global hotkey brings elegant overlay

---

## 🏗️ Technical Architecture

### Technology Stack

| Layer | Technology | Rationale |
|-------|-----------|-----------|
| **Frontend** | Tauri 2.0 + React + TypeScript | Native performance, 8.6MB vs Electron's 244MB |
| **Runtime** | Bun 1.35+ | Fast package management, native ESM |
| **ML Inference** | Python + MLX + parakeet-tdt | Optimized for Apple Silicon, 25 languages |
| **Native APIs** | Swift | Global hotkeys, audio capture, text insertion |
| **Styling** | TailwindCSS + Framer Motion | Rapid development, beautiful animations |
| **State** | Zustand | Lightweight, TypeScript-first |

### System Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    UI Layer (React)                      │
│  ┌────────────┐  ┌──────────┐  ┌───────────────────┐  │
│  │  Recording │  │  Menu    │  │  Settings/        │  │
│  │  Modal     │  │  Bar     │  │  Onboarding       │  │
│  └────────────┘  └──────────┘  └───────────────────┘  │
└─────────────────────────────────────────────────────────┘
                          ↕ IPC (Tauri)
┌─────────────────────────────────────────────────────────┐
│              Application Layer (Rust/Tauri)              │
│  • State management      • System tray integration      │
│  • IPC handlers          • Auto-updates                 │
└─────────────────────────────────────────────────────────┘
         ↕                          ↕                    ↕
┌─────────────────┐  ┌──────────────────────┐  ┌──────────────┐
│  Native Layer   │  │   ML Inference       │  │  Storage     │
│    (Swift)      │  │  (Python + MLX)      │  │   Layer      │
│                 │  │                      │  │              │
│ • Global hotkey │  │ • Model loading      │  │ • Config     │
│ • Audio capture │  │ • Preprocessing      │  │ • History    │
│ • Accessibility │  │ • Speech-to-text     │  │ • Prefs      │
│ • Text insert   │  │ • Language detection │  │              │
└─────────────────┘  └──────────────────────┘  └──────────────┘
```

### Data Flow

1. **Trigger**: User presses global hotkey (⌘⌃Space)
2. **UI**: Beautiful modal overlay appears with recording indicator
3. **Capture**: Swift captures microphone audio via Core Audio
4. **Stream**: Audio chunks sent to Python MLX backend
5. **Process**: Real-time transcription using parakeet-tdt-0.6b-v3
6. **Insert**: Transcribed text inserted into active application
7. **Feedback**: Smooth animation, subtle success indicator

---

## 🎨 UI/UX Design Specification

### Core User Flows

#### 1. Recording Flow
```
Press ⌘⌃Space
    ↓
Elegant modal fades in (200ms spring)
    ↓
Visual waveform animation (real-time audio feedback)
    ↓
Release key or click → Processing state
    ↓
Text appears in active app
    ↓
Modal fades out (300ms) with success micro-interaction
```

#### 2. Settings Flow
```
Click menu bar icon
    ↓
Popover appears with quick actions
    ↓
Click "Preferences" → Settings window
    ↓
Tabs: General | Hotkeys | Languages | Advanced
```

#### 3. First-Time Onboarding
```
Launch app → Welcome screen
    ↓
Request accessibility permissions (clear explanation)
    ↓
Configure global hotkey (suggest ⌘⌃Space)
    ↓
Test recording with visual feedback
    ↓
Success! → Show tips overlay
```

### Visual Design System

#### Colors (Warm Minimalism)
```css
--primary: #F59E0B;      /* Amber 500 - warm, energetic */
--primary-dark: #D97706; /* Amber 600 */
--background: #FAFAF9;   /* Warm gray 50 */
--surface: #FFFFFF;      /* Pure white */
--surface-frosted: rgba(255, 255, 255, 0.8); /* Frosted glass */
--text-primary: #1C1917; /* Stone 900 */
--text-secondary: #78716C; /* Stone 500 */
--success: #10B981;      /* Emerald 500 */
--error: #EF4444;        /* Red 500 */
```

#### Typography
```css
--font-ui: 'SF Pro Display', system-ui;
--font-mono: 'Berkeley Mono', 'SF Mono', monospace;

/* Scale */
--text-xs: 11px;
--text-sm: 13px;
--text-base: 15px;
--text-lg: 18px;
--text-xl: 24px;
--text-2xl: 32px;
```

#### Spacing (8px base unit)
```css
--space-1: 4px;
--space-2: 8px;
--space-3: 12px;
--space-4: 16px;
--space-6: 24px;
--space-8: 32px;
--space-12: 48px;
--space-16: 64px;
```

#### Animations
```css
/* Spring curve - feels native to macOS */
--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1);

/* Subtle, gentle movements */
--duration-fast: 150ms;
--duration-base: 250ms;
--duration-slow: 400ms;
```

### Component Designs

#### Recording Modal
- **Size**: 480px × 200px, centered on screen
- **Background**: Frosted glass effect with subtle shadow
- **Border**: 1px solid rgba(0,0,0,0.1), 12px radius
- **Content**:
  - Large microphone icon (animated pulse while recording)
  - Real-time waveform visualization (amber gradient)
  - Status text: "Listening..." / "Processing..." / "Done!"
  - Subtle keyboard shortcut hint at bottom

#### Menu Bar Popover
- **Size**: 280px × auto, positioned below menu bar icon
- **Sections**:
  - Quick stats: "X words today"
  - Recent transcriptions (last 3, truncated)
  - Divider
  - "Preferences..." button
  - "Quit" button

#### Settings Window
- **Size**: 640px × 480px
- **Tabs**: General | Hotkeys | Languages | Advanced
- **Style**: Native macOS preferences feel
- **General Tab**:
  - Launch at login (toggle)
  - Auto-insert text (toggle)
  - Copy to clipboard (toggle)
- **Hotkeys Tab**:
  - Record: [⌘⌃Space] (editable)
  - Stop: [Release] or [Esc]
- **Languages Tab**:
  - Default: English (dropdown)
  - Auto-detect language (toggle)
  - Supported languages list (25 total)

---

## 🛠️ Implementation Plan

### Phase 1: Foundation (Week 1-2)
- [ ] Set up Tauri 2.0 project with Bun
- [ ] Configure TypeScript, ESLint, Prettier
- [ ] Create basic React app with Vite
- [ ] Set up Tailwind + design tokens
- [ ] Implement basic menu bar integration
- [ ] Create settings window UI (no functionality)

**Deliverables**: Basic app shell, menu bar icon, settings UI

### Phase 2: Native Integration (Week 2-3)
- [ ] Swift bridge for global hotkeys ([HotKey library](https://github.com/soffes/HotKey))
- [ ] Implement audio capture using Core Audio
- [ ] Request accessibility permissions
- [ ] Text insertion into active apps
- [ ] System notifications for errors

**Deliverables**: Working hotkey registration, audio capture

### Phase 3: ML Integration (Week 3-4)
- [ ] Set up Python environment with MLX
- [ ] Install [parakeet-mlx](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3)
- [ ] Create Python bridge for model inference
- [ ] Implement real-time audio streaming
- [ ] Add model warm-up on app launch
- [ ] Test transcription accuracy

**Deliverables**: Working speech-to-text pipeline

### Phase 4: UI Polish (Week 4-5)
- [ ] Design and implement recording modal
- [ ] Add waveform visualization (Canvas API)
- [ ] Implement spring animations (Framer Motion)
- [ ] Create onboarding flow
- [ ] Add loading states and error handling
- [ ] Implement dark mode support

**Deliverables**: Beautiful, polished UI with animations

### Phase 5: Features & Testing (Week 5-6)
- [ ] Transcription history (local storage)
- [ ] Language switching
- [ ] Keyboard shortcuts for settings
- [ ] Auto-updater integration
- [ ] Performance optimization
- [ ] User testing and feedback iteration

**Deliverables**: Feature-complete app

### Phase 6: Distribution (Week 6-7)
- [ ] Code signing setup
- [ ] Notarization for macOS
- [ ] Create DMG installer
- [ ] Write comprehensive README
- [ ] Create demo video/GIF
- [ ] App Store submission (optional)

**Deliverables**: Distributable app

---

## 📦 Dependencies

### Frontend (Bun + npm)
```json
{
  "dependencies": {
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "@tauri-apps/api": "^2.0.0",
    "@tauri-apps/plugin-shell": "^2.0.0",
    "zustand": "^5.0.0",
    "framer-motion": "^11.0.0",
    "lucide-react": "^0.index": "2"
  },
  "devDependencies": {
    "@tauri-apps/cli": "^2.0.0",
    "typescript": "^5.7.0",
    "vite": "^6.0.0",
    "@vitejs/plugin-react": "^4.3.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0",
    "vitest": "^2.0.0",
    "eslint": "^9.0.0",
    "prettier": "^3.0.0"
  }
}
```

### Backend (Python)
```txt
mlx>=0.21.0
parakeet-mlx>=0.1.0
numpy>=2.0.0
soundfile>=0.12.0
```

### Native (Swift)
- HotKey (via Swift Package Manager)
- No additional dependencies (using built-in frameworks)

---

## 🔒 macOS Permissions Required

1. **Microphone Access** - For audio recording
2. **Accessibility** - For text insertion into other apps
3. **Input Monitoring** - For global hotkeys (macOS 10.15+)

All permissions will be requested with clear explanations during onboarding.

---

## 🎯 Success Metrics

- **Performance**: < 100ms latency from speech end to text insertion
- **Size**: < 50MB app bundle (excluding ML models)
- **Accuracy**: > 95% transcription accuracy for clear English
- **UX**: Onboarding completion > 90%
- **Privacy**: 100% local processing, zero network calls

---

## 📚 References

### Technical Documentation
- [MLX Framework](https://github.com/ml-explore/mlx) - Apple's ML framework for Apple Silicon
- [Parakeet TDT Model](https://huggingface.co/mlx-community/parakeet-tdt-0.6b-v3) - Speech recognition model
- [Tauri 2.0 Docs](https://v2.tauri.app/) - Desktop app framework
- [Core Audio Guide](https://developer.apple.com/library/archive/documentation/MusicAudio/Conceptual/CoreAudioOverview/) - macOS audio APIs
- [HotKey Library](https://github.com/soffes/HotKey) - Global shortcuts for macOS

### Design Inspiration
- [HashiCorp Tao](https://www.hashicorp.com/en/tao-of-hashicorp) - Product design philosophy
- [Helios Design System](https://helios.hashicorp.design/about) - HashiCorp's design system
- Superwhisper - Reference for UX excellence

### Community Resources
- [mlx-audio](https://github.com/Blaizzy/mlx-audio) - Speech-to-text library for MLX
- [Tauri vs Electron Comparison](https://www.gethopp.app/blog/tauri-vs-electron) - Framework decision rationale

---

## 💡 Future Enhancements

- **Multi-language support**: Expand beyond English
- **Custom vocabulary**: Add technical terms, names
- **Snippets**: Save and reuse common phrases
- **Punctuation commands**: Voice-controlled punctuation
- **Cloud sync**: Optional iCloud sync for settings
- **iOS companion**: Dictate on iPhone, insert on Mac

---

## 🤝 Contributing

This project follows TDD principles:
1. Write tests first (RED)
2. Implement minimal code (GREEN)
3. Refactor (REFACTOR)

See [AGENTS.md](/workspace/AGENTS.md) for development guidelines.

---

**Ready to build something beautiful? Let's make speech-to-text delightful! 🎙️✨**
