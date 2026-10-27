# HeSwitch — Architecture, Design Decisions & Developer Guide

This document provides a comprehensive technical overview of **HeSwitch**, including the background research on reference projects (**Ne-To** and **Keyboop**), the Hebrew-specific linguistic and keyboard challenges, the current system architecture, and the roadmap for future development.

---

## 1. Executive Summary & Philosophy

**HeSwitch** is a native macOS menu bar application designed to seamlessly and automatically correct text typed in the wrong Hebrew or English keyboard layout.

### Guiding Principles:
1. **100% Local & Privacy-First:** No network requests, telemetry, or external AI/LLM calls. All spellchecking is performed on-device via Apple's built-in `NSSpellChecker`.
2. **Clipboard Respect:** Does not overwrite or corrupt the user's system clipboard during normal text replacement.
3. **Conservative Decision Engine:** False positives (accidentally replacing words the user intended to type) are far worse than missing an occasional typo. When in doubt, HeSwitch does not convert.
4. **Zero Heavy Dependencies:** Written entirely in modern Swift using standard Apple frameworks (`SwiftUI`, `AppKit`, `Carbon`, `ApplicationServices`). Builds in seconds with standard Xcode Command Line Tools.

---

## 2. Research & Analysis of Reference Projects

### A. Ne-To (`YATP-Dev/Ne-To`)
- **Key Strengths:**
  - Extremely lightweight (~1,500 lines of Swift total).
  - Excellent macOS Accessibility integration (`AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`) to inspect and replace text directly in memory.
  - Automatically enables dormant accessibility trees in Electron/Chromium apps (`AXManualAccessibility`).
  - Gracefully ignores secure text fields (passwords) for security (`kAXSecureTextFieldSubrole`, `IsSecureEventInputEnabled()`).
  - Dual-mode trigger: instant reaction on delimiters (Space/Return) + secondary check after a short typing pause (~350ms) for multi-word phrases.
- **Limitations:**
  - Built specifically for Russian/English; keymaps and dictionaries are Cyrillic-centric.
  - Hardcoded layout mapping rather than dynamic layout detection.

### B. Keyboop (`iffuno/keyboop`)
- **Key Strengths:**
  - **`DynamicKeymap` via `UCKeyTranslate`:** Interrogates macOS Carbon APIs to extract active layout data and construct physical keymaps dynamically, regardless of which keyboard layout variant the user has installed.
  - **Spotlight / Autocomplete Protection:** Discovered that in Spotlight, Safari, and Chrome address bars, sending a Backspace removes the highlighted auto-completion rather than the typed letter. Solved this using a targeted forward-delete / selection check.
  - **Numeric Separator Protection:** Protects commas and periods between digits (e.g. `3.14` or `1,000`) so they are never treated as letters.
  - **`UndoLearner`:** If a user hits Backspace immediately following an automatic replacement, the app cancels the layout switch and temporarily learns to ignore that token.
- **Limitations:**
  - Heavy monolithic codebase (35,000+ lines, C++ whisper.cpp integration for voice typing, Neural Engine models, Metal, and Sparkle). Difficult to maintain or audit for a dedicated layout switcher.

---

## 3. Hebrew $\leftrightarrow$ English Linguistic & Physical Mapping

Standard Israeli keyboards (SI-1452 and macOS "Hebrew" / "Hebrew - PC") present unique challenges that do not exist in Latin or Cyrillic languages:

### A. Punctuation Keys Producing Letters
Several physical keys that produce punctuation in QWERTY produce essential Hebrew letters:

| Physical Key | English (QWERTY) | Hebrew Layout | Significance / Examples |
| :---: | :---: | :---: | :--- |
| `,` (comma) | `,` | **ת** (Tav) | Ubiquitous: `אתה` = `t,v`, `את` = `t,`, `בית` = `ch,`, `מתי` = `n,h` |
| `.` (period) | `.` | **ץ** (Tsadi Sofit) | E.g. `רוץ` = `rum.` |
| `;` (semicolon) | `;` | **ף** (Pe Sofit) | E.g. `סוף` = `suc;` |
| `'` (apostrophe)| `'` | **,** (Hebrew comma) | Physical apostrophe key produces Hebrew comma |
| `w` | `w` | **'** (Geresh) | Physical `W` key produces Hebrew Geresh |
| `q` | `q` | **/** (Slash) | |
| `/` (slash) | `/` | **.** (Full stop) | |

> **Critical Rule:** In `WordBoundary.precedingWord`, punctuation characters like `,`, `.`, `;`, `'` must be treated as valid word characters when evaluating English-to-Hebrew candidates.

### B. Case Sensitivity Handling
Hebrew has **no uppercase letters**.
- When converting from English to Hebrew: Both lowercase and uppercase characters (`akuo`, `Akuo`, `AKUO`) map to the same Hebrew letters (`שלום`).
- When converting from Hebrew to English: Text is converted to lowercase by default.

### C. Acronyms & Abbreviations (Gershayim & Geresh)
Hebrew frequently uses:
- **Gershayim (`"`):** Used for acronyms (e.g. `צה"ל` = `mv"k`, `ת"א` = `,"t`, `חו"ל` = `ju"k`, `ארה"ב` = `trv"c`, `מנכ"ל` = `nbf"k`).
- **Geresh (`'`):** Used for modified sounds (e.g. `צ'יפס` = `m'hpx` / `mwhpx`) and single-letter abbreviations (`ד'`, `ה'`).
- The parser and converter preserve quotes within tokens without splitting words.

### D. Physical Key `W`, Hebrew Geresh (`׳` U+05F3) & Apostrophe (`'`)
On macOS standard Hebrew keyboard layout, physical key `W` produces:
- **`׳` (Hebrew Geresh, Unicode U+05F3)** or ASCII `'` (U+0027).
- In earlier versions, words starting or ending with `w` in Hebrew layout (e.g. `׳ישא` for `what`, `ים׳` for `how`, `׳םרךג` for `world`) failed because:
  1. `׳` was preserved as literal punctuation during conversion, leaving words like `׳hat` and `ho׳`.
  2. Mixed-script validation rejected words containing both ASCII English letters and Hebrew scalar U+05F3.
- **Resolution:**
  - `LayoutConversion.heToEn` explicitly maps `׳`, `'`, and `’` (U+2019) to `w`.
  - `LayoutConversion.enToHe` maps `w` and `W` to `׳`.
  - A dedicated pre-pass detects English words typed with Hebrew Geresh (e.g. `׳hat` ➔ `what`, `ho׳` ➔ `how`, `to׳er` ➔ `tower`) and converts them to valid English candidates.

### E. Ambiguous Collisions
A small set of high-frequency 2-letter words exist legally in both English and Hebrew:
- `to` ↔ `אם`
- `do` ↔ `גם`
- `go` ↔ `עם`
- `so` ↔ `דם`
- `no` ↔ `נם`
- `an` ↔ `שם`
- `ha` ↔ `יש`
- `nut` ↔ `הוא`

These words are guarded in `AmbiguousCollisions.swift` and are **never** auto-switched in isolation without surrounding context or a manual shortcut trigger.

---

## 4. Codebase Architecture

```
HeSwitch/Sources/HeSwitch/
├── HeSwitchApp.swift               # Application entry point, NSApplication delegate, MenuBarExtra UI, event loop
├── SettingsView.swift              # Native SwiftUI preferences (General, Shortcuts, Custom Dictionary, Exclusions)
├── LaunchAtLogin.swift             # Dual-engine autorun (SMAppService + AppleScript System Events fallback)
├── DecisionEngine.swift            # Linguistic arbitration: spellchecking, high-frequency fast-paths, collision filters
├── HighFrequencyVocabulary.swift   # Top-frequency English & Hebrew word sets to bypass morphological false-positives
├── LayoutConversion.swift          # QWERTY ↔ SI-1452 character maps, Geresh/W handling, decimal guards
├── KeystrokeBuffer.swift           # In-memory FIFO keystroke ring buffer for Terminal/CLI/iTerm support
├── KeyboardReplacement.swift       # Direct AX memory injection & fallback synthetic CGEvent backspaces
├── FocusedText.swift               # Accessibility AXUIElement snapshot reader and memory replacer
├── WordBoundary.swift              # Word extraction, delimiter detection, punctuation trimming
├── KeyboardLayoutService.swift     # Carbon TIS layout query and input source selection (TISSelectInputSource)
├── DoubleTapDetector.swift         # Double-tap modifier detection (Shift, Control, Option, Command)
├── AmbiguousCollisions.swift       # Whitelist of dual-language collisions
├── CustomDictionary.swift          # User-defined whitelist stored in UserDefaults
├── ApplicationExclusions.swift     # Per-application disabling of auto-switch
└── SwitchSoundPlayer.swift         # Auditory feedback via NSSound
```

### Key Subsystems:

#### A. Fast-Path Vocabulary (`HighFrequencyVocabulary.swift`)
Hebrew morphology (`NSSpellChecker`) frequently treats arbitrary Hebrew character sequences as valid prefixed forms (e.g. `ש` [that] + `מ` [from] + `ג` as a valid form of letter `ג`). To prevent words like `שמג` from staying unconverted when the user intended `and`, top-frequency words in English (`and`, `what`, `how`, `world`, `the`, `you`) and Hebrew (`שלום`, `בוקר`, `מה`, `טוב`) bypass morphological ambiguities and switch instantly.

#### B. Launch at Startup (`LaunchAtLogin.swift`)
Because ad-hoc signed apps (distributed without a paid Apple Developer certificate) can fail when registering via `SMAppService.mainApp.register()`, `LaunchAtLogin` implements a resilient hybrid approach:
1. Attempts `SMAppService.mainApp` (macOS 13+ standard).
2. If registration fails or throws an error, seamlessly executes an AppleScript snippet via `NSAppleScript` targeting `System Events`:
   ```applescript
   tell application "System Events"
       make login item at end with properties {path: "/Applications/HeSwitch.app", name: "HeSwitch", hidden: false}
   end tell
   ```
3. Checks both `SMAppService` status and `System Events` login items for the current state.

#### C. Automated Permission Reset & Quarantine Removal (`install.sh` & In-App)
macOS Gatekeeper attaches `com.apple.quarantine` to downloaded `.zip` releases, causing Gatekeeper to execute the app from a randomized read-only folder (`/private/var/folders/.../AppTranslocation/...`). This prevents persistent Accessibility TCC grants across restarts.
- **`install.sh`:** Automatically curls the latest GitHub release, unzips to `/Applications/HeSwitch.app`, removes quarantine (`xattr -cr /Applications/HeSwitch.app`), resets stale TCC accessibility cache (`tccutil reset Accessibility com.hebrew.HeSwitch`), launches the app, and opens System Settings.
- **In-App Self-Healing:** The Settings window and Menu Bar menu feature a **"Reset & Fix Permissions (Automated)"** button that runs `xattr -cr` and `tccutil reset` directly from the app.
HeSwitch/
├── Package.swift                             # SwiftPM configuration (.executableTarget, macOS 14+)
├── README.md                                 # User-facing guide and installation
├── ARCHITECTURE.md                           # This document
├── LICENSE                                   # MIT License
├── Scripts/
│   └── package-app.sh                        # Packages release binary into dist/HeSwitch.app
├── .github/
│   └── workflows/
│       └── build.yml                         # Automated macOS CI/CD pipeline
├── Sources/
│   └── HeSwitch/
│       ├── HeSwitchApp.swift                 # App lifecycle, event monitors, and timers
│       ├── LayoutConversion.swift            # 1-to-1 physical translation matrix
│       ├── WordBoundary.swift                # Token boundaries & Hebrew punctuation parsing
│       ├── DecisionEngine.swift              # NSSpellChecker evaluation & phrase logic
│       ├── AmbiguousCollisions.swift         # False-positive collision prevention
│       ├── KeyboardLayoutService.swift       # Carbon TIS layout switcher (TISSelectInputSource)
│       ├── FocusedText.swift                 # Accessibility (AXUIElement) reader & direct editor
│       ├── KeyboardReplacement.swift         # Keystroke synthesis fallback (CGEvent unicode injection)
│       ├── DoubleTapDetector.swift           # Double-tap modifier detection (Shift/Option/Cmd)
│       ├── ShortcutEventTap.swift            # CGEventTap session listener for keyboard chords
│       ├── CustomDictionary.swift            # User-saved dictionary (stored in UserDefaults)
│       ├── ApplicationExclusions.swift       # App bundle blacklist (terminals, games, IDEs)
│       ├── SwitchSoundPlayer.swift           # Native audio feedback (AudioServices)
│       └── SettingsView.swift                # SwiftUI Preferences window
└── Tests/
    └── HeSwitchTests/
        └── HebrewConversionTests.swift       # Unit test suite (32 assertions)
```

---

## 5. Runtime Execution Flow

```
[Key Down Event] (NSEvent global monitor)
       │
       ├── Tagged with 0x48655377 ("HeSw")? ──> Ignore (our own synthetic event)
       │
       ├── Delimiter Key (Space / Return)?
       │      │
       │      └── Sleep 35ms ──> Check if cursor/field unchanged
       │                            │
       │                            ├── WordBoundary.precedingWord()
       │                            ├── DecisionEngine.candidate()
       │                            │     ├── LayoutConversion.convert()
       │                            │     ├── NSSpellChecker validation
       │                            │     └── AmbiguousCollisions check
       │                            │
       │                            └── [Replace Text]
       │                                  ├── 1. Direct AXUIElement edit (fastest)
       │                                  └── 2. Keystroke Backspaces + Unicode
       │                                  │
       │                                  └── TISSelectInputSource(targetLayout)
       │
       └── Natural Typing Pause (~350ms)?
              │
              ├── DecisionEngine.phraseCandidate() ──> Repair whole line if multi-word mismatch
              └── WordBoundary.recentCompletedWords() ──> Repair trailing completed word
```

---

## 6. Build & CI/CD Pipeline

### Local Build:
```sh
cd HeSwitch
# Run tests
swift test

# Build and package into dist/HeSwitch.app
bash Scripts/package-app.sh
```

### GitHub Actions CI (`.github/workflows/build.yml`):
- Runs on `macos-14` (Apple Silicon M-series runner).
- Executes `swift test` against the full test suite.
- Runs `Scripts/package-app.sh` to generate the `.app` bundle, inject `Info.plist`, and apply code signing.
- Compresses the bundle into `HeSwitch-macOS.zip` and uploads it as a build artifact.

---

## 7. Roadmap & Future Improvements

1. **`DynamicKeymap` Support (`UCKeyTranslate`):**
   - Query `TISCopyCurrentKeyboardLayoutInputSource()` and call Carbon's `UCKeyTranslate` to dynamically map keycodes to characters.
   - Allows automatic adaptation if the user chooses **Hebrew - QWERTY** (phonetic layout) or custom user-defined keyboard layouts.
2. **`UndoLearner` Heuristic:**
   - If an automatic replacement triggers and the user immediately hits `Backspace`, revert the replacement, switch the input source back, and add the word to a temporary session ignore list.
3. **Spotlight / Browser Address Bar Autocomplete Guard:**
   - Detect when an application has active autocomplete selection (`AXScreenCheck.hasSelection()`) and issue a forward delete before sending backspaces so the first typed character is not orphaned.
4. **Custom App Menu Bar Icon:**
   - Add a custom vector/template menu bar icon displaying a subtle Hebrew Alef / English A toggle symbol in addition to text status.
5. **Apple Notarization:**
   - Configure Developer ID signing identity (`codesign`) and `xcrun notarytool` in GitHub Actions for seamless Gatekeeper approval on fresh Macs without requiring right-click Open.
