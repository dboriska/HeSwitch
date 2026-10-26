# HeSwitch 🇮🇱 🔀 🇬🇧

**HeSwitch** is a lightweight, native macOS menu bar app that automatically repairs words and phrases typed in the wrong Hebrew or English keyboard layout.

It runs 100% locally on your Mac, respects your clipboard, and uses macOS built-in spellchecking and Carbon Text Input Services. No internet, no background tracking, no heavy AI models.

---

## ✨ Features

- **Automatic Repair on Space or Return:**
  Instantly repairs words typed in the wrong layout:
  - `akuo` ➔ `שלום`
  - `nv bang` ➔ `מה נשמע`
  - `cuer yuc` ➔ `בוקר טוב`
  - `יקךךם` ➔ `hello`
  - `'םרךג` ➔ `world`
  - `בםגק` ➔ `code`
- **Hebrew Punctuation & Letter Mapping:**
  Correctly converts Hebrew letters that live on punctuation keys:
  - `t,v` ➔ `אתה` (since `,` is `ת`)
  - `t,` ➔ `את`
  - `rum.` ➔ `רוץ` (since `.` is `ץ`)
  - `suc;` ➔ `סוף` (since `;` is `ף`)
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
  Disable automatic repair in code editors, terminals, or games via the native Settings window. Add company names or slang to the custom dictionary.

---

## 🚀 Building & Running

### Requirements
- macOS 13 (Ventura) or later
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
swift test
```

### Package into `.app` Bundle
To produce `dist/HeSwitch.app`:
```sh
bash Scripts/package-app.sh
```
Move `dist/HeSwitch.app` to `/Applications` and launch it.

---

## 🔒 Permissions Required

When running for the first time, macOS will ask for:
1. **Accessibility (`AXUIElement`):** Required to read the focused text field and replace mistyped characters.
2. **Input Monitoring (`CGEventTap`):** Required to catch the double-tap modifier shortcut and typing delimiters.

---

## 📄 License
MIT License.
