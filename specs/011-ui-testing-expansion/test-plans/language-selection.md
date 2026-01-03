# Language Selection Test Plans

**Related Views**: `LanguagePicker.swift`, `SettingsView.swift` (Language Tab)
**Priority**: Medium

## UI Component Analysis

### LanguagePicker Structure

```
┌─────────────────────────────────────────────┐
│  🔍 Search languages...              [✕]   │  ← Search Field
├─────────────────────────────────────────────┤
│  ○  English                           ✓    │
│     English                                 │
├─────────────────────────────────────────────┤
│  ●  French                            ✓    │  ← Selected (amber)
│     Français                                │
├─────────────────────────────────────────────┤
│  ○  German                            ⬇    │  ← Not downloaded
│     Deutsch                                 │
├─────────────────────────────────────────────┤
│  ○  Spanish                           ⚠    │  ← Download error
│     Español                                 │
└─────────────────────────────────────────────┘
```

### Supported Languages (25)

```swift
LanguageModel.supportedLanguages
// en, fr, de, es, it, pt, nl, pl, ru, uk, zh, ja, ko, ar, hi, ...
```

---

## Test Cases

### T01: testLanguagePickerOpens

**Objective**: Verify language picker is accessible in settings

**Preconditions**:

- App launched with `--skip-onboarding`
- Settings window open, Language tab selected

**Steps**:

1. Open Settings (⌘,)
2. Click "Language" in sidebar
3. Observe language picker

**Expected Results**:

- Language picker visible
- Search field present with placeholder "Search languages..."
- Scrollable list of 25 languages
- Currently selected language highlighted with amber background
- Each language shows: name, native name, download status

**UI Elements**:

```swift
app.windows["Settings"]
app.outlines.staticTexts["Language"] // Sidebar tab
app.textFields["Search languages"] // Search field
app.scrollViews // Language list
app.buttons.matching(identifier: "languageRow") // Language rows
```

---

### T02: testLanguageSearchFilters

**Objective**: Verify search filters languages correctly

**Preconditions**:

- Language picker visible

**Steps**:

1. Type "fr" in search field
2. Observe filtered results
3. Clear search
4. Type "日本" (Japanese in native script)

**Expected Results**:

- Search by code: "fr" → French visible
- Search by name: "fren" → French visible
- Search by native name: "Français" → French visible
- Clear button (✕) appears when text entered
- List updates instantly on each keystroke
- Empty search shows all 25 languages

**Code Reference** (`LanguagePicker.swift:26-35`):

```swift
private var filteredLanguages: [LanguageModel] {
    if searchText.isEmpty {
        return LanguageModel.supportedLanguages
    }
    return LanguageModel.supportedLanguages.filter { language in
        language.name.localizedCaseInsensitiveContains(searchText) ||
        language.nativeName.localizedCaseInsensitiveContains(searchText) ||
        language.code.localizedCaseInsensitiveContains(searchText)
    }
}
```

---

### T03: testLanguageChangeUpdatesUI

**Objective**: Verify selecting a language updates all relevant UI

**Preconditions**:

- Language picker visible
- Current language: English

**Steps**:

1. Click on "French" row
2. Observe UI updates

**Expected Results**:

1. **Language Picker**:
   - French row gets amber background (15% opacity)
   - Checkmark icon changes from circle to checkmark.circle.fill
   - Previous selection (English) loses highlight

2. **Settings Footer**:
   - Save indicator shows (checkmark or spinner)

3. **Recording Modal** (if opened):
   - Language flag changes to 🇫🇷

**Code Reference** (`LanguagePicker.swift:69-79`):

```swift
LanguageRow(
    language: language,
    isSelected: language.code == selectedLanguageCode,
    onSelect: {
        selectedLanguageCode = language.code
        Task { await onLanguageSelected(language) }
    }
)
```

---

### T04: testLanguagePersistedAcrossLaunches

**Objective**: Verify language selection persists after app restart

**Preconditions**:

- App running

**Steps**:

1. Open Settings → Language
2. Select "German" (de)
3. Close app
4. Relaunch app
5. Open Settings → Language

**Expected Results**:

- German still selected after relaunch
- `UserDefaults` key `defaultLanguage` = "de"
- Recording modal shows 🇩🇪 flag

**Persistence Check**:

```swift
// In test
let defaults = UserDefaults.standard
XCTAssertEqual(defaults.string(forKey: "defaultLanguage"), "de")
```

---

### T05: testLanguageDownloadStatus

**Objective**: Verify download status badges display correctly

**Preconditions**:

- Language picker visible

**Test Matrix**:

| Status | Icon | Color |
|--------|------|-------|
| `.downloaded` | checkmark.circle.fill | green |
| `.downloading` | ProgressView | - |
| `.notDownloaded` | arrow.down.circle | secondary |
| `.error` | exclamationmark.triangle.fill | orange |

**Expected Results**:

- Each language row shows appropriate status badge
- Badges are right-aligned in row
- ProgressView animates during download

**Code Reference** (`LanguagePicker.swift:145-167`):

```swift
@ViewBuilder
private var downloadStatusBadge: some View {
    switch language.downloadStatus {
    case .downloaded:
        Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
    case .downloading:
        ProgressView().scaleEffect(0.7)
    case .notDownloaded:
        Image(systemName: "arrow.down.circle")
    case .error:
        Image(systemName: "exclamationmark.triangle.fill")
            .foregroundStyle(.orange)
    }
}
```

---

### T06: testLanguageSwitchDuringRecording

**Objective**: Verify language can be switched during active recording

**Preconditions**:

- Recording modal open and recording

**Steps**:

1. Start recording in English
2. Trigger language switch notification (via hotkey or menu)
3. Observe UI updates

**Expected Results**:

1. Language flag updates in recording modal header
2. Spinner appears next to flag during switch
3. `isLanguageSwitching = true` during transition
4. FluidAudioService switches model
5. Recording continues uninterrupted

**Code Reference** (`RecordingViewModel.swift:154-169`):

```swift
private func handleLanguageSwitch(to languageCode: String) async {
    isLanguageSwitching = true
    currentLanguage = languageCode
    do {
        try await fluidAudioService.switchLanguage(to: languageCode)
    } catch {
        errorMessage = "Failed to switch language: \(error.localizedDescription)"
    }
    isLanguageSwitching = false
}
```

---

### T07: testAutoDetectLanguageToggle

**Objective**: Verify auto-detect language toggle works

**Preconditions**:

- Settings → Language tab open

**Steps**:

1. Toggle "Automatically detect language" ON
2. Observe UI changes
3. Toggle OFF

**Expected Results**:

- Toggle persists to UserDefaults
- When ON: Language picker may be disabled or show "Auto" option
- When OFF: Manual language selection active

**UI Element**:

```swift
app.toggles["Automatically detect language"]
```

---

## Accessibility Tests

### T08: testLanguagePickerAccessibility

**Objective**: Verify VoiceOver announces language information correctly

**Expected Accessibility Labels**:

```swift
// Language row
"\(language.name), \(isSelected ? "selected" : "not selected"), \(downloadStatusText)"

// Accessibility hints
isSelected ? "Currently selected language" : "Double tap to select this language"

// Search field
"Search languages"

// Clear button
"Clear search"
```

---

## Test Infrastructure

### Mock Language Model Service

```swift
class MockLanguageModelService {
    var downloadStatuses: [String: LanguageModel.DownloadStatus] = [
        "en": .downloaded,
        "fr": .downloaded,
        "de": .notDownloaded,
        "es": .error
    ]

    func simulateDownload(language: String) async {
        downloadStatuses[language] = .downloading
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        downloadStatuses[language] = .downloaded
    }
}
```

### Test Helpers

```swift
extension XCUIApplication {
    var languagePicker: XCUIElement {
        scrollViews.containing(.textField, identifier: "Search languages").element
    }

    func selectLanguage(_ name: String) {
        let row = buttons.matching(NSPredicate(format: "label CONTAINS %@", name)).firstMatch
        row.tap()
    }

    func searchLanguage(_ query: String) {
        let searchField = textFields["Search languages"]
        searchField.tap()
        searchField.typeText(query)
    }
}
```

---

## Acceptance Criteria

- [ ] All 8 test cases implemented and passing
- [ ] Search functionality tested with various inputs
- [ ] Language persistence verified across app restarts
- [ ] Download status badges display correctly
- [ ] Accessibility labels verified with VoiceOver
- [ ] Tests run in < 30 seconds total
