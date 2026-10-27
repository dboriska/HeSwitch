# HeSwitch 🇮🇱 🔀 🇬🇧

**HeSwitch** is a lightweight, native macOS menu bar app that automatically repairs words and phrases typed in the wrong Hebrew or English keyboard layout.

It runs 100% locally on your Mac, respects your clipboard, and uses macOS built-in spellchecking and Carbon Text Input Services. No internet, no background tracking, no heavy AI models.

---

## ⚡ Quick Install & Auto-Update (One Command)

To install or automatically update HeSwitch to the latest version (with automatic quarantine clearing and permission reset):

```sh
curl -fsSL https://raw.githubusercontent.com/dboriska/HeSwitch/main/install.sh | bash
```

This single command:
1. Downloads the latest release from GitHub.
2. Closes any running instance and installs into `/Applications/HeSwitch.app`.
3. Clears macOS Gatekeeper quarantine (`xattr -cr`) to prevent App Translocation issues.
4. Resets stale TCC accessibility caches (`tccutil reset Accessibility com.hebrew.HeSwitch`).
5. Launches HeSwitch and opens System Settings directly to the Accessibility pane.

---

## ✨ Features

- **Automatic Repair on Space or Return:**
  Instantly repairs words typed in the wrong layout:
  - `akuo` ➔ `שלום`
  - `nv bang` ➔ `מה נשמע`
  - `cuer yuc` ➔ `בוקר טוב`
  - `יקךךם` ➔ `hello`
  - `׳םרךג` or `'םרךג` ➔ `world`
  - `בםגק` ➔ `code`
  - `שמג` ➔ `and`
- **Full Hebrew Geresh (`׳`) & Key `W` Handling:**
  On macOS Hebrew layout, the physical `W` key produces the Hebrew Geresh (`׳` U+05F3) or `'`. HeSwitch provides complete bi-directional support:
  - `׳ישא` or `'ישא` ➔ `what`
  - `ים׳` or `ים'` ➔ `how`
  - `׳יקמ` ➔ `when`
  - `׳יקרק` ➔ `where`
  - `׳יט` ➔ `why`
  - `׳hat` ➔ `what` (mixed Geresh English words)
  - `ho׳` ➔ `how`
  - `to׳er` ➔ `tower`
- **Terminal, CLI & iTerm Support:**
  Uses a keystroke ring buffer fallback to automatically replace mistyped words even in non-accessible command-line environments (Terminal.app, iTerm2, Alacritty, Warp).
- **Launch at Startup (Login Items):**
  Toggle "Launch at Startup" right from the menu bar or Settings window. Uses macOS `SMAppService` with an automatic AppleScript `System Events` fallback for ad-hoc signed releases.
- **Self-Healing Permission Reset:**
  If macOS gets stuck repeatedly asking for Accessibility permission after an update or Gatekeeper quarantine, click **"Reset & Fix Permissions (Automated)"** in the menu or Settings. It strips quarantine and resets the macOS TCC database cleanly.
- **Hebrew Punctuation & Letter Mapping:**
  Correctly converts Hebrew letters that live on punctuation keys:
  - `t,v` ➔ `אתה` (since `,` is `ת`)
  - `t,` ➔ `את`
  - `ru.` ➔ `רוץ` (since `.` is `ץ`)
  - `xu;` ➔ `סוף` (since `;` is `ף` and `x` is `ס`)
- **Hebrew Acronyms & Abbreviations:**
  Supports Gershayim (`"`) and Geresh (`'`):
  - `mv"k` ➔ `צה"ל`
  - `,"t` ➔ `ת"א`
  - `ju"k` ➔ `חו"ל`
  - `trv"c` ➔ `ארה"ב`
  - `m'hpx` or `mwhpx` ➔ `צ'יפס`
- **Double-Tap Shift (Manual Repair):**
  Tap **Shift twice** to immediately convert selected text or the word preceding the cursor and toggle between Hebrew and English.
- **Short-Word Ambiguity Protection:**
  Words that are valid in both languages (such as `to` ↔ `אם`, `do` ↔ `גם`, `go` ↔ `עם`, `so` ↔ `דם`) are protected from false-positive automatic switches.
- **Number & Decimal Protection:**
  Decimals and list numbers like `3.14` or `1,000` are never corrupted into Hebrew letters.
- **Whole-Phrase Repair:**
  Typing quickly in the wrong layout across multiple words is automatically caught and repaired after a natural typing pause (~350ms).
- **Application Exclusions & Custom Dictionary:**
  Disable automatic repair in code editors or games via the native Settings window. Add company names or slang to the custom dictionary.

---

## 🚀 Building & Running from Source

### Requirements
- macOS 14 (Sonoma) or later
- Xcode or Xcode Command Line Tools (`xcode-select --install`)
- Enabled English and Hebrew input sources in macOS System Settings

### Build & Run
```sh
cd HeSwitch
swift build
swift run HeSwitch
```

### Run Tests
```sh
cd HeSwitch
swift test
```

### Package into `.app` Bundle
To produce `dist/HeSwitch.app`:
```sh
cd HeSwitch
bash Scripts/package-app.sh
```
Move `dist/HeSwitch.app` to `/Applications` and launch it.

---

## 🔒 Permissions

When running for the first time, macOS requires:
- **Accessibility (`AXUIElement`):** Required to read the focused text field and replace mistyped characters.

If permissions ever get out of sync after an update, run `bash install.sh` or click **"Reset & Fix Permissions"** in the app.

---

## 📄 License
MIT License.
