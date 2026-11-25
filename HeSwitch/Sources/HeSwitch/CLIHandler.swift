import AppKit
import ApplicationServices
import Carbon
import Foundation

@MainActor
public enum CLIHandler {
    /// Returns true if CLI handled an exit-terminal command (like --help, --test, --diagnose),
    /// or false if normal app execution should continue (or if --verbose mode is active).
    public static func handleCommandLineArguments() -> Bool {
        let args = CommandLine.arguments

        // If launched normally (args contains only executable path, or macOS launch args like -psn_...)
        let filteredArgs = args.dropFirst().filter { !$0.hasPrefix("-psn_") }
        guard let first = filteredArgs.first else {
            return false
        }

        switch first {
        case "-h", "--help", "help":
            printUsage()
            return true

        case "--version", "-V":
            print("HeSwitch \(AppUpdater.currentVersion)")
            return true

        case "-d", "--diagnose", "--check", "diagnose":
            runDiagnostics()
            return true

        case "-t", "--test", "test":
            runSelfTests()
            return true

        case "-c", "--convert", "convert":
            let text = filteredArgs.dropFirst().joined(separator: " ")
            if text.isEmpty {
                print("Error: --convert requires text to convert. e.g. HeSwitch --convert akuo")
            } else {
                runConversion(text)
            }
            return true

        case "-v", "--verbose", "--monitor", "-m":
            CLILogger.isVerbose = true
            print("""
            ================================================================================
             HeSwitch \(AppUpdater.currentVersion) — Live Foreground Monitor Mode
            ================================================================================
             Listening for global keystrokes and accessibility events...
             Switch to another app (TextEdit, Apple Notes, Safari, Terminal) and type.
             Press Ctrl+C in this terminal window to stop.
            ================================================================================
            """)
            fflush(stdout)
            return false

        case "--reset-permissions":
            resetPermissions()
            return true

        default:
            print("Unknown option: \(first)")
            printUsage()
            return true
        }
    }

    private static func printUsage() {
        print("""
        HeSwitch — Native Hebrew/English Keyboard Auto-Switcher for macOS
        Version: \(AppUpdater.currentVersion)

        Usage:
          HeSwitch [options]

        Options:
          -d, --diagnose        Run comprehensive system diagnostic check (TCC, secure input, layouts)
          -v, --verbose         Run in foreground monitor mode (logs live keystrokes, decisions & switches)
          -t, --test            Run built-in verification suite on linguistic algorithms and dictionaries
          -c, --convert <text>  Convert text from command line and display decision analysis
          --reset-permissions   Clear quarantine & reset macOS Accessibility TCC permissions
          --version             Print version number
          -h, --help            Show this help message

        Examples:
          /Applications/HeSwitch.app/Contents/MacOS/HeSwitch --diagnose
          /Applications/HeSwitch.app/Contents/MacOS/HeSwitch --verbose
          /Applications/HeSwitch.app/Contents/MacOS/HeSwitch --convert "akuo"
          /Applications/HeSwitch.app/Contents/MacOS/HeSwitch --convert "יקךךם"
        """)
        fflush(stdout)
    }

    private static func runDiagnostics() {
        print("""
        ================================================================================
         HeSwitch System Diagnostic Report (\(AppUpdater.currentVersion))
        ================================================================================
        """)

        var allPass = true

        // 1. Accessibility Trust Check
        let isTrusted = AXIsProcessTrusted()
        if isTrusted {
            print("  [PASS] Accessibility (AXUIElement): Granted ✓")
        } else {
            allPass = false
            print("  [FAIL] Accessibility (AXUIElement): NOT GRANTED ✗")
            print("         HeSwitch cannot read text fields or replace words.")
            print("         Fix: System Settings → Privacy & Security → Accessibility → Enable HeSwitch")
        }

        // 2. Input Monitoring Check
        let listenAccess = CGPreflightListenEventAccess()
        if listenAccess {
            print("  [PASS] Input Monitoring: Granted ✓")
        } else {
            print("  [WARN] Input Monitoring: Not explicitly granted (May use Accessibility fallback)")
        }

        // 3. Secure Event Input Check
        let secureInput = IsSecureEventInputEnabled()
        if !secureInput {
            print("  [PASS] Secure Event Input: Inactive (Normal keystroke flow) ✓")
        } else {
            allPass = false
            print("  [FAIL] Secure Event Input: ACTIVE ✗")
            print("         Another process has locked global event monitoring!")
            print("         (Common culprits: 1Password, Bitwarden, Terminal 'Secure Keyboard Entry', password fields)")
            print("         To identify the locking process, run in Terminal:")
            print("           ioreg -l -w 0 | grep -i SecureInput")
        }

        // 4. App Translocation Check
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains("AppTranslocation") {
            allPass = false
            print("  [FAIL] App Translocation: ACTIVE ✗")
            print("         Running from randomized sandbox: \(bundlePath)")
            print("         Permissions will NOT persist across reboots while translocated.")
            print("         Fix: Move HeSwitch.app to /Applications and run:")
            print("           xattr -cr /Applications/HeSwitch.app")
        } else {
            print("  [PASS] App Location: Standard bundle path (\(bundlePath)) ✓")
        }

        // 5. Keyboard Layout Check via Carbon TIS
        let sources = (TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource]) ?? []
        var foundEnglish = false
        var foundHebrew = false

        for source in sources {
            if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
                let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
                if languages.contains(where: { $0.lowercased().hasPrefix("he") || $0.lowercased().hasPrefix("iw") }) {
                    foundHebrew = true
                }
                if languages.contains(where: { $0.lowercased().hasPrefix("en") }) {
                    foundEnglish = true
                }
            }
            if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
                let sourceID = (Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String).lowercased()
                if sourceID.contains("hebrew") { foundHebrew = true }
                if sourceID.contains(".us") || sourceID.contains(".abc") || sourceID.contains("english") { foundEnglish = true }
            }
        }

        if foundEnglish && foundHebrew {
            print("  [PASS] Input Sources: Both English and Hebrew layouts detected in macOS ✓")
        } else {
            allPass = false
            print("  [FAIL] Input Sources: Missing required layout! (English: \(foundEnglish ? "✓" : "MISSING ✗"), Hebrew: \(foundHebrew ? "✓" : "MISSING ✗"))")
            print("         Fix: System Settings → Keyboard → Text Input → Add both English and Hebrew")
        }

        // 6. Frontmost Application Accessibility Inspection
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontApp.localizedName ?? "Unknown"
            let bundleID = frontApp.bundleIdentifier ?? "Unknown"
            let pid = frontApp.processIdentifier
            print("  [INFO] Frontmost App: \(appName) (ID: \(bundleID), PID: \(pid))")

            let axApp = AXUIElementCreateApplication(pid)
            var focusedRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
               let focusedRef, CFGetTypeID(focusedRef) == AXUIElementGetTypeID() {
                let focusedElement = focusedRef as! AXUIElement
                var roleRef: CFTypeRef?
                _ = AXUIElementCopyAttributeValue(focusedElement, kAXRoleAttribute as CFString, &roleRef)
                let role = (roleRef as? String) ?? "Unknown"
                print("  [INFO] Focused Element Role: \(role) ✓")
            } else {
                print("  [WARN] Focused UI element in frontmost app could not be queried via AXUIElement")
            }
        }

        print("--------------------------------------------------------------------------------")
        if allPass {
            print("  RESULT: All core system prerequisites PASSED! HeSwitch is ready to operate.")
        } else {
            print("  RESULT: One or more prerequisites FAILED. Follow the instructions above to fix.")
        }
        print("================================================================================\n")
        fflush(stdout)
    }

    private static func runSelfTests() {
        print("""
        ================================================================================
         HeSwitch Self-Test Verification Suite
        ================================================================================
        """)

        let testCases: [(input: String, expected: String, desc: String)] = [
            ("akuo", "שלום", "EN -> HE (Basic greeting)"),
            ("nv bang", "מה נשמע", "EN -> HE (Multi-word phrase)"),
            ("cuer yuc", "בוקר טוב", "EN -> HE (Morning greeting)"),
            ("t,v", "אתה", "EN -> HE (Punctuation Tav)"),
            ("t,", "את", "EN -> HE (Punctuation Tav short)"),
            ("fi", "כן", "EN -> HE (Short word 'כן')"),
            ("kph", "לפי", "EN -> HE (Neutral sentence opener 'לפי')"),
            ("what", "׳ישא", "EN -> HE (Direct layout transcoder)"),
            ("יקךךם", "hello", "HE -> EN (Greeting)"),
            ("׳םרךג", "world", "HE -> EN (Geresh 'w' layout)"),
            ("בםגק", "code", "HE -> EN (Developer word)"),
            ("טקד", "yes", "HE -> EN (Affirmative)"),
            ("שמג", "and", "HE -> EN (Conjunction)"),
            ("׳hat", "what", "Mixed Geresh W ('what')"),
            ("ho׳", "how", "Mixed Geresh W ('how')"),
        ]

        var passedCount = 0
        for tc in testCases {
            let actual = LayoutConversion.convert(tc.input)?.output
            if actual == tc.expected {
                passedCount += 1
                print("  [PASS] \(tc.input) -> \(actual ?? "") (\(tc.desc))")
            } else {
                print("  [FAIL] \(tc.input) -> expected '\(tc.expected)', got '\(actual ?? "nil")' (\(tc.desc))")
            }
        }

        // Test ambiguous collisions (should be preserved when uncertain)
        let collisions = ["to", "do", "go", "so"]
        var collisionPassed = 0
        for word in collisions {
            if AmbiguousCollisions.isAmbiguous(word) {
                collisionPassed += 1
            }
        }

        print("--------------------------------------------------------------------------------")
        print("  Conversions: \(passedCount)/\(testCases.count) passed")
        print("  Collisions:  \(collisionPassed)/\(collisions.count) protected")
        if passedCount == testCases.count && collisionPassed == collisions.count {
            print("  RESULT: ALL TESTS PASSED (100% Accuracy) ✓")
        } else {
            print("  RESULT: Some tests failed!")
        }
        print("================================================================================\n")
        fflush(stdout)
    }

    private static func runConversion(_ text: String) {
        print("--- HeSwitch Conversion Analysis ---")
        print("Input:          '\(text)'")

        if let conversion = LayoutConversion.convert(text) {
            print("Source Layout:  \(conversion.source.rawValue)")
            print("Target Layout:  \(conversion.target.rawValue)")
            print("Output:         '\(conversion.output)'")

            if let candidate = DecisionEngine.candidate(for: text, context: nil) {
                print("Decision:       AUTO-REPAIR APPROVED -> '\(candidate.output)' (\(candidate.source.rawValue) -> \(candidate.target.rawValue))")
            } else {
                print("Decision:       PRESERVED (Not flagged as layout error; left untouched)")
            }
        } else {
            print("Output:         No valid layout mapping available for input.")
        }
        fflush(stdout)
    }

    private static func resetPermissions() {
        print("==> Resetting HeSwitch quarantine and macOS Accessibility permissions...")
        let appPath = "/Applications/HeSwitch.app"

        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-cr", appPath]
        try? xattr.run()
        xattr.waitUntilExit()

        let tcc = Process()
        tcc.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        tcc.arguments = ["reset", "Accessibility", "com.hebrew.HeSwitch"]
        try? tcc.run()
        tcc.waitUntilExit()

        print("==> Opening System Settings → Accessibility...")
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        print("==> Done. Please enable HeSwitch in the System Settings window that just opened.")
        fflush(stdout)
    }
}
