# HeSwitch — Architecture, Design Decisions & Developer Guide

This document provides a comprehensive technical reference for **HeSwitch**, detailing its research foundations, Hebrew $\leftrightarrow$ English linguistic intricacies, system architecture, runtime execution pipeline, testing methodologies with massive corpora, and development history.

---

## 1. Executive Summary & Philosophy

**HeSwitch** is a native, ultra-lightweight macOS menu bar application designed to automatically detect and repair words and phrases typed in the wrong Hebrew or English keyboard layout.

### Guiding Principles:
1. **100% Local & Privacy-First:** No network requests, telemetry, or external AI/LLM dependencies. All spellchecking and linguistic arbitration is performed locally on-device using Apple's native `NSSpellChecker` and embedded high-frequency lexicons.
2. **Clipboard Respect:** HeSwitch never touches, inspects, or overwrites the macOS system clipboard during text replacement.
3. **Conservative Decision Engine (Zero False Positives):** Accidentally altering a word that the user intended to type is far more disruptive than missing an occasional mistyped word. When in doubt, HeSwitch preserves the user's text untouched.
4. **Pure Native Swift & Frameworks:** Built purely in modern Swift with standard Apple frameworks (`SwiftUI`, `AppKit`, `Carbon`, `ApplicationServices`, `ServiceManagement`). Compiles in seconds with standard Xcode Command Line Tools without third-party dependencies.

---

## 2. Research & Comparative Analysis of Reference Projects

Before development, two key reference repositories were deeply analyzed:

### A. Ne-To (`YATP-Dev/Ne-To`)
- **Key Strengths:**
  - Extremely lightweight architecture (~1,500 lines of Swift total).
  - Excellent macOS Accessibility integration (`AXUIElementCopyAttributeValue`, `AXUIElementSetAttributeValue`) allowing in-place memory replacement without simulating backspaces.
  - Automatically enables dormant accessibility trees in Chromium/Electron applications via `AXManualAccessibility`.
  - Secure input handling: gracefully ignores password fields (`kAXSecureTextFieldSubrole`, `IsSecureEventInputEnabled()`).
  - Dual-mode trigger: immediate reaction on delimiters (Space/Return) paired with a debounce timer (~350ms) for multi-word phrase repair.
- **Limitations:**
  - Hardcoded for Russian/English (Cyrillic layout); incapable of handling Hebrew punctuation letters or Geresh/Gershayim.
  - Required both Accessibility and Input Monitoring permissions simultaneously, triggering permission loops on macOS 14+ Sonoma.

### B. Keyboop (`iffuno/keyboop`)
- **Key Strengths:**
  - **`DynamicKeymap` via `UCKeyTranslate`:** Interrogates Carbon APIs to dynamically extract keyboard layout keymaps.
  - **Numeric Separator Protection:** Protects numbers with periods or commas (e.g. `3.14` or `1,000`) from letter substitution.
  - **Autocomplete Guard:** Protects browser address bars and Spotlight searches from backspace auto-completion corruption.
- **Limitations:**
  - Heavy monolithic codebase (35,000+ lines, C++ whisper.cpp integration for voice typing, Neural Engine models, Metal). Too heavy and complex for an agile, auditable layout switcher.

---

## 3. Hebrew $\leftrightarrow$ English Linguistic & Physical Mapping

Standard Israeli keyboards (SI-1452 and macOS "Hebrew" / "Hebrew - PC") introduce unique linguistic and layout challenges:

### A. Punctuation Keys Producing Letters
Several physical keys that produce punctuation in US QWERTY produce essential Hebrew letters:

| Physical Key | English (QWERTY) | Hebrew Layout | Significance / Examples |
| :---: | :---: | :---: | :--- |
| `,` (comma) | `,` | **ת** (Tav) | Ubiquitous: `אתה` = `t,v`, `את` = `t,`, `בית` = `ch,`, `מתי` = `n,h` |
| `.` (period) | `.` | **ץ** (Tsadi Sofit) | E.g. `רוץ` = `ru.`, `חפץ` = `ec.` |
| `;` (semicolon) | `;` | **ף** (Pe Sofit) | E.g. `סוף` = `xu;`, `כוף` = `fu;` |
| `'` (apostrophe)| `'` | **,** (Hebrew comma) | Physical apostrophe key produces Hebrew comma |
| `w` | `w` | **׳** (Geresh) / **'** | Physical `W` key produces Hebrew Geresh |
| `q` | `q` | **/** (Slash) | Physical `Q` key produces Hebrew slash |
| `/` (slash) | `/` | **.** (Full stop) | Physical slash key produces Hebrew full stop |

> **Rule:** In `WordBoundary.precedingWord`, characters like `,`, `.`, `;`, `'` must be parsed as potential Hebrew letters rather than token boundaries when evaluating layout conversion.

### B. The Letter `W`, Hebrew Geresh (`׳` U+05F3) & Apostrophe (`'`)
On macOS Hebrew layout:
- The physical `W` key produces **`׳` (Hebrew Geresh, Unicode U+05F3)** or ASCII `'` (U+0027).
- In earlier versions, words starting or ending with `w` in Hebrew layout (e.g. `׳ישא` for `what`, `ים׳` for `how`, `׳םרךג` for `world`) failed because:
  1. `׳` was preserved as literal punctuation during conversion, resulting in `׳hat` and `ho׳`.
  2. Mixed-script validation rejected words containing both ASCII English letters and Hebrew scalar U+05F3.
- **Resolution:**
  - `LayoutConversion.heToEn` explicitly maps `׳` (U+05F3), `'` (U+0027), and `’` (U+2019) to `w`.
  - `LayoutConversion.enToHe` maps `w` and `W` to `׳`.
  - A dedicated pre-pass detects English words typed with Hebrew Geresh (e.g. `׳hat` ➔ `what`, `ho׳` ➔ `how`, `to׳er` ➔ `tower`) and converts them to valid English candidates.

### C. Morphological & Archaic Root Collisions:
Standard dictionary validation (`NSSpellChecker`) struggles with Hebrew lexical overlaps:
1. **Hebrew Prefix Morphology False-Positives (e.g. `שמג` ➔ `and`):**
   Hebrew morphology allows prefixes `ש-` (that), `מ-` (from), `ב-` (in), `ל-` (to), `כ-` (as), `ו-` (and), `ה-` (the) to attach to words. `NSSpellChecker` often accepts arbitrary letter combinations (such as `שמג` as `ש` + `מ` + `ג`).
2. **Archaic Biblical/Literary Roots (e.g. `שגג` ➔ `add`):**
   `שגג` (*shagag*) is a legitimate biblical Hebrew verb meaning *"to err"* (the root of *שגגה*). When a user typed `add` on Hebrew layout (`שגג`), `NSSpellChecker` reported `שגג` as valid Hebrew, suppressing the conversion!
3. **Common Technical Abbreviations & File Extensions (e.g. `צג` ➔ `md`):**
   `צג` (*tsag*) in modern Hebrew means *"display / monitor / screen"*. When a user types `צג` or a markdown filename like `README.צג`, `NSSpellChecker` reports `צג` as valid Hebrew.
   - **Resolution:** `md` is prioritized in `HighFrequencyVocabulary`, and `WordBoundary.precedingWord` cleanly isolates file extensions so `README.צג` ➔ `README.md` and standalone `צג` ➔ `md`.
- **Resolution (`HighFrequencyVocabulary.swift`):**
  A curated high-frequency priority lexicon in English (`and`, `add`, `md`, `what`, `how`, `when`, `where`, `world`, `git`, `code`, `app`, `dev`, `run`, `log`, etc.) bypasses morphological ambiguity, ensuring common English words and developer keywords always convert immediately.

### D. Ambiguous Collisions (Protected Words)
A small set of high-frequency words exist legally in both English and Hebrew:
- `to` ↔ `אם`
- `do` ↔ `גם`
- `go` ↔ `עם`
- `so` ↔ `דם`
- `no` ↔ `נם`
- `an` ↔ `שם`
- `re` ↔ `רק`
- `bang` ↔ `נשמע`
- `ha` ↔ `יש`
- `nut` ↔ `הוא`

These words are guarded in `AmbiguousCollisions.swift` and are **never** auto-switched in isolation without surrounding context or manual double-tap trigger.

---

## 4. Codebase Architecture

```
HeSwitch/Sources/HeSwitch/
├── HeSwitchApp.swift               # Application entry point, MenuBarExtra UI, event loop, self-healing
├── SettingsView.swift              # Native SwiftUI preferences (General, Shortcuts, Custom Dictionary, Exclusions)
├── LaunchAtLogin.swift             # Dual-engine autorun (SMAppService + AppleScript System Events fallback)
├── DecisionEngine.swift            # Linguistic arbitration: spellcheck, priority fast-paths, collision filters
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

#### A. Keystroke Ring Buffer for Non-Accessible Apps (`KeystrokeBuffer.swift`)
Terminal applications (Terminal.app, iTerm2, Alacritty, Warp) do not expose their text contents via `AXUIElementCopyAttributeValue(kAXValueAttribute)`.
- HeSwitch implements an in-memory 64-character ring buffer tracking recent keystrokes.
- On Space/Return in terminal apps, HeSwitch retrieves the completed word from `KeystrokeBuffer`, checks the `DecisionEngine`, and uses `KeyboardReplacement.replace(backspaces: N, with: text)` to emit synthetic backspaces and unicode characters.

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

---

## 5. Runtime Execution Flow

```
[Key Down Event] (NSEvent global monitor)
       │
       ├── Tagged with 0x48655377 ("HeSw")? ──> Ignore (our own synthetic event)
       │
       ├── Delimiter Key (Space / Return)?
       │      │
       │      ├── KeystrokeBuffer.onDelimiter() ──> Update in-memory buffer
       │      │
       │      └── FocusedText.read()
       │             ├── Available? (GUI Apps) ──> WordBoundary.precedingWord()
       │             └── Nil? (CLI/Terminals)   ──> KeystrokeBuffer.currentWord
       │                    │
       │                    └── DecisionEngine.candidate()
       │                          ├── AmbiguousCollisions check? ──> Suppress
       │                          ├── English source valid?       ──> Suppress
       │                          ├── HighFrequencyVocabulary?    ──> Convert!
       │                          └── NSSpellChecker validation   ──> Convert if target valid
       │                                 │
       │                                 └── [Replace Text]
       │                                       ├── 1. Direct AX memory edit (GUI apps)
       │                                       └── 2. Synthetic Backspaces + Unicode (Terminals)
       │                                       │
       │                                       └── TISSelectInputSource(targetLayout)
       │
       └── Natural Typing Pause (~350ms)?
              │
              ├── DecisionEngine.phraseCandidate() ──> Repair whole line if multi-word mismatch
              └── WordBoundary.recentCompletedWords() ──> Repair trailing completed word
```

---

## 6. Massive Vocabulary Testing & Benchmark Results

To validate the engine against real-world language without regression, HeSwitch includes two automated test suites:
- [`test_layout_switcher.py`](file:///home/db/myai/autoSwithc_he_eng/test_layout_switcher.py): Quick verification of core linguistic rules (2,000+ trials).
- [`test_huge_vocabulary.py`](file:///home/db/myai/autoSwithc_he_eng/test_huge_vocabulary.py): Large-scale stress test evaluating 20,000+ trials against a massive 189,018-word corpus:
  - **Hspell 1.4 Lexicon:** 129,586 authentic Hebrew words.
  - **Google Frequency Dataset:** Top 10,000 English words.
  - **Comprehensive English Lexicon:** 59,432 words.

### Benchmark Evaluation Metrics (20,402 Trials):
```
=====================================================================================
        HeSwitch Massive Vocabulary & Stress Evaluation Report
=====================================================================================
Loaded English Vocabulary:     59,435 words
Loaded Hebrew Vocabulary:      129,586 words (Hspell)
Total Corpus Size:             189,021 words
Executed Typing Trials:        20,402
Execution Duration:            0.19 seconds (109,837 words/sec)
-------------------------------------------------------------------------------------
Accuracy:                      98.69%
Precision:                     100.00% (Integrity of conversions — ZERO corruptions)
Recall:                        98.11% (Mistyped words detected and repaired)
Specificity:                   100.00% (Valid words preserved)
F1 Score:                      99.04%
-------------------------------------------------------------------------------------
True Positives  (TP):          13,829   (Correctly switched wrong layout)
True Negatives  (TN):          6,306    (Correctly kept legitimate words)
False Positives (FP):          0        (CORRUPTIONS: Legitimate typing altered)
False Negatives (FN):          267      (Safely skipped ambiguous words)
=====================================================================================
```

---

## 7. Release History & Milestones

- **`v1.0.0` (Initial Release):**
  - Core QWERTY $\leftrightarrow$ SI-1452 physical mapping.
  - `AXUIElement` direct text replacement and `NSSpellChecker` arbitration.
  - Double-tap Shift manual shortcut and MenuBarExtra UI.
- **`v1.0.1` (Terminal/CLI & Fast-Path):**
  - Added `KeystrokeBuffer.swift` for Terminal.app, iTerm2, Alacritty, Warp.
  - Added `HighFrequencyVocabulary.swift` to solve morphology ambiguity for `and` (`שמג`).
- **`v1.0.2` (Permission Loop Fix):**
  - Removed buggy `CGPreflightListenEventAccess()` check on macOS 14 Sonoma.
  - Reduced permissions to Accessibility only. Embedded `--identifier "com.hebrew.HeSwitch"`.
- **`v1.0.3` (Letter W, Auto-Reset, Launch at Startup):**
  - Full bidirectional mapping for physical `W` key (`׳` U+05F3, `'`, `’`).
  - Added mixed Geresh recovery (`׳hat` ➔ `what`, `ho׳` ➔ `how`, `to׳er` ➔ `tower`).
  - Added `install.sh` and in-app self-healing permission reset (`xattr -cr` + `tccutil reset`).
  - Added Launch at Startup (Login Items) with `SMAppService` + AppleScript fallback.
- **`v1.0.4` (Fix `add` / `שגג` & Developer Vocabulary):**
  - Solved `שגג` archaic Hebrew root collision by prioritizing `add`.
  - Added developer keywords (`app`, `run`, `log`, `fix`, `dev`, `api`, `url`, `cmd`, `init`, `save`, `load`).

---

## 8. Build & CI/CD Pipeline

### Local Build:
```sh
cd HeSwitch
swift build
swift test
bash Scripts/package-app.sh
```

### One-Command Install / Update:
```sh
curl -fsSL https://raw.githubusercontent.com/dboriska/HeSwitch/main/install.sh | bash
```

---

## 9. Release History & Milestones

- **`v1.0.0` (Initial Release):**
  - Core QWERTY $\leftrightarrow$ SI-1452 physical mapping.
  - `AXUIElement` direct text replacement and `NSSpellChecker` arbitration.
  - Double-tap Shift manual shortcut and MenuBarExtra UI.
- **`v1.0.1` (Terminal/CLI & Fast-Path):**
  - Added `KeystrokeBuffer.swift` for Terminal.app, iTerm2, Alacritty, Warp.
  - Added `HighFrequencyVocabulary.swift` to solve morphology ambiguity for `and` (`שמג`).
- **`v1.0.2` (Permission Loop Fix):**
  - Removed buggy `CGPreflightListenEventAccess()` check on macOS 14 Sonoma.
  - Reduced permissions to Accessibility only. Embedded `--identifier "com.hebrew.HeSwitch"`.
- **`v1.0.3` (Letter W, Auto-Reset, Launch at Startup):**
  - Full bidirectional mapping for physical `W` key (`׳` U+05F3, `'`, `’`).
  - Added mixed Geresh recovery (`׳hat` ➔ `what`, `ho׳` ➔ `how`, `to׳er` ➔ `tower`).
  - Added `install.sh` and in-app self-healing permission reset (`xattr -cr` + `tccutil reset`).
  - Added Launch at Startup (Login Items) with `SMAppService` + AppleScript fallback.
- **`v1.0.4` (Fix `add` / `שגג` & Developer Vocabulary):**
  - Solved `שגג` archaic Hebrew root collision by prioritizing `add`.
  - Added developer keywords (`app`, `run`, `log`, `fix`, `dev`, `api`, `url`, `cmd`, `init`, `save`, `load`).
- **`v1.0.5` (Markdown `.md` / `צג` Support & Boundary Splitting):**
  - Added `md` ↔ `צג` developer keyword conversion.
  - Added smart extension boundary parsing for filenames (`README.צג` ➔ `README.md`).
- **`v1.0.6` (Fix Backspace Blacklisting & Universal Extension Splitting):**
  - **Removed session blacklisting (`sessionIgnoredWords`)**: Pressing Backspace by mistake or to delete trailing characters no longer disables transcoding for that word in the future.
  - **Natural Backspace Passthrough**: Restored standard non-destructive Backspace behavior so normal editing is never hijacked.
  - **Universal Terminal & Accessible Extension Support**: CLI / Terminal keystroke buffer now splits file extensions via `WordBoundary.extractFileExtension`, enabling `cat README.צג ` ➔ `cat README.md ` across all environments.
- **`v1.0.7` (Capitalized English Transcoding, Smart Backspace & Selection Transcoder):**
  - **Capitalized English Words on Hebrew Layout**: Converts words starting with Shift / uppercase Latin (`Wישא` ➔ `What`, `Hקךךם` ➔ `Hello`, `Pךקשדק` ➔ `Please`, `Hם׳` ➔ `How`, `Tישמלד` ➔ `Thanks`), preserving capitalization.
  - **Smart Backspace (Option A)**: 1-Tap instant revert on auto-repair without any session blacklist. Words are never permanently blocked.
  - **In-Place Selection Transcoder (Option 1 - `Cmd + Shift + X`)**: Highlight any sentence or paragraph in any macOS app (or Menu Bar item) to transcode between Hebrew and English in-place, preserving whitespace, punctuation, and layout.

---

## 10. Comparative Feature Study & Development Roadmap

Analysis of reference applications (**Punto Switcher**, **Caramba Switcher**, **Keyboop**, **Ne-To**, and **LangOver / הפוך על הפוך**) reveals key high-value capabilities:

| Feature | Reference Source | Status | Purpose & Mechanism |
| :--- | :--- | :---: | :--- |
| **1. Smart Backspace (`Option A`)** | Punto, Caramba | **Implemented in v1.0.7** | 1-Tap instant revert immediately after auto-repair with zero session blacklisting. |
| **2. Selection Converter (`Cmd + Shift + X`)** | LangOver, Ne-To | **Implemented in v1.0.7** | Select any paragraph or sentence, press `⌘⇧X` to invert language in-place (with universal clipboard fallback). |
| **3. Trackpad Haptic Feedback** | Ne-To | Planned (Tier 1) | Subtle `NSHapticFeedbackManager` tactile tap on trackpad when layout flips silently. |
| **4. Spotlight / URL Bar Autocomplete Guard** | Keyboop | Planned (Tier 1) | Check `kAXSelectedTextAttribute` so backspace doesn't delete active autocompletions in Chrome/Safari/Spotlight. |
| **5. Instant `Caps Lock` Toggle** | Caramba | Planned (Tier 2) | Tap `Caps Lock` for zero-lag language toggle without macOS HUD delay (holding 0.5s preserves uppercase lock). |
| **6. BiDi Reversed Hebrew Fixer** | LangOver (ReverseIt) | Planned (Tier 2) | Inverts character order for Hebrew in non-RTL apps (Photoshop, CAD, subtitle editors) where `שלום` displays as `םולש`. |
| **7. Dynamic Carbon `UCKeyTranslate`** | Keyboop | Planned (Tier 2) | Dynamically queries active layout map from macOS Carbon API to automatically support Hebrew - PC and phonetic layouts. |
| **8. Native Vector Menu Bar Icon** | Native macOS | Planned (Tier 3) | Minimal dual-language template glyph (`A / א`) matching dark/light mode with live visual indicator. |
| **9. In-App Auto-Update Checker** | Native / Sparkle | Planned (Tier 3) | GUI button in Settings checking GitHub API for seamless single-click update. |

