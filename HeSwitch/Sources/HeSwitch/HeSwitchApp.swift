import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@main
struct HeSwitchApp: App {
    @StateObject private var model = HeSwitchModel.shared

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading, spacing: 10) {
                Text("HeSwitch")
                    .font(.headline)

                Text(model.statusText)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if !model.hasRequiredAccess {
                    Divider()
                    Text("Accessibility permission is required.")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Grant Accessibility Access…") {
                        model.requestPermissions()
                    }
                    Button("Reset & Fix Permissions…") {
                        model.resetPermissionsAndQuarantine()
                    }
                }

                Divider()

                Toggle("Launch at Startup", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))

                Divider()

                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                Button("Quit HeSwitch") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(12)
            .frame(width: 260)
            .onAppear {
                model.start()
            }
        } label: {
            Text(model.currentLayout?.rawValue ?? "EN/HE")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}

@MainActor
public final class HeSwitchModel: ObservableObject {
    public static let shared = HeSwitchModel()

    @Published public var automaticRepair: Bool {
        didSet { UserDefaults.standard.set(automaticRepair, forKey: "automaticRepair") }
    }
    @Published public var playSound: Bool {
        didSet { UserDefaults.standard.set(playSound, forKey: "playSound") }
    }
    @Published public private(set) var currentLayout: KeyboardLanguage?
    @Published public private(set) var hasAccessibilityAccess = false
    @Published public private(set) var hasInputMonitoringAccess = false
    @Published public private(set) var launchAtLogin = false
    @Published public private(set) var customWords = CustomDictionary.words
    @Published public private(set) var excludedApplications = ApplicationExclusions.applications
    @Published public private(set) var previousWordShortcut: ManualShortcut
    @Published public private(set) var statusText = "Ready"

    public var hasRequiredAccess: Bool { hasAccessibilityAccess }

    private let keyboard = KeyboardLayoutService()
    private let soundPlayer = SwitchSoundPlayer()
    private var keyMonitor: Any?
    private var flagsMonitor: Any?
    private var layoutTimer: Timer?
    private var accessTimer: Timer?
    private var doubleTap = DoubleTapDetector()
    private var revision = 0
    private var started = false

    private init() {
        automaticRepair = UserDefaults.standard.object(forKey: "automaticRepair") as? Bool ?? true
        playSound = UserDefaults.standard.object(forKey: "playSound") as? Bool ?? true
        previousWordShortcut = .doubleTap(.shift)
        currentLayout = keyboard.currentLayout
        refreshPermissions()
        refreshLaunchAtLogin()
    }

    public func start() {
        guard !started else { return }
        started = true

        // Check for macOS App Translocation
        let bundlePath = Bundle.main.bundlePath
        if bundlePath.contains("AppTranslocation") {
            NSLog("[HeSwitch] Warning: App running under macOS App Translocation. Removing quarantine on /Applications/HeSwitch.app...")
            let xattr = Process()
            xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattr.arguments = ["-cr", "/Applications/HeSwitch.app"]
            try? xattr.run()
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleKey(event) }
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor [weak self] in self?.handleFlags(event) }
        }

        layoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentLayout = self.keyboard.currentLayout
            }
        }

        accessTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshPermissions()
                self.refreshLaunchAtLogin()
            }
        }
    }

    public func refreshPermissions() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        hasInputMonitoringAccess = CGPreflightListenEventAccess()
    }

    public func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityAccess = trusted
        if !trusted {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Self-healing automated permission reset: clears quarantine and resets TCC cache
    public func resetPermissionsAndQuarantine() {
        let bundlePath = Bundle.main.bundlePath

        // 1. Clear quarantine on current running bundle
        let xattr = Process()
        xattr.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        xattr.arguments = ["-cr", bundlePath]
        try? xattr.run()
        xattr.waitUntilExit()

        // 2. Also clear quarantine on /Applications/HeSwitch.app
        if bundlePath != "/Applications/HeSwitch.app" && FileManager.default.fileExists(atPath: "/Applications/HeSwitch.app") {
            let xattrApp = Process()
            xattrApp.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
            xattrApp.arguments = ["-cr", "/Applications/HeSwitch.app"]
            try? xattrApp.run()
            xattrApp.waitUntilExit()
        }

        // 3. Reset TCC accessibility database for com.hebrew.HeSwitch
        let tcc = Process()
        tcc.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        tcc.arguments = ["reset", "Accessibility", "com.hebrew.HeSwitch"]
        try? tcc.run()
        tcc.waitUntilExit()

        // 4. Trigger permission prompt
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)

        // 5. Open System Settings to Accessibility
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }

        refreshPermissions()
    }

    public func refreshLaunchAtLogin() {
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.setEnabled(enabled)
        refreshLaunchAtLogin()
    }

    public func setPreviousWordShortcut(_ shortcut: ManualShortcut) {
        previousWordShortcut = shortcut
    }

    public func addCustomWord(_ word: String) -> Bool {
        guard CustomDictionary.add(word) else { return false }
        customWords = CustomDictionary.words
        return true
    }

    public func removeCustomWord(_ word: String) {
        CustomDictionary.remove(word)
        customWords = CustomDictionary.words
    }

    public func addExcludedApplication(bundleID: String, name: String) -> Bool {
        guard ApplicationExclusions.add(bundleID: bundleID, name: name) else { return false }
        excludedApplications = ApplicationExclusions.applications
        return true
    }

    public func removeExcludedApplication(_ bundleID: String) {
        ApplicationExclusions.remove(bundleID: bundleID)
        excludedApplications = ApplicationExclusions.applications
    }

    private func handleKey(_ event: NSEvent) {
        if event.cgEvent?.getIntegerValueField(.eventSourceUserData) == KeyboardReplacement.eventTag { return }
        revision &+= 1
        doubleTap.keyPressed()

        // Reset keystroke buffer on modifier shortcuts (Cmd+C, Cmd+V, etc.)
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            KeystrokeBuffer.shared.clear()
            return
        }

        // Backspace key: update keystroke buffer naturally without hijacking or blacklisting
        if event.keyCode == 51 {
            KeystrokeBuffer.shared.backspace()
            return
        }

        // Navigation keys (Escape, Arrows)
        if [53, 123, 124, 125, 126].contains(event.keyCode) {
            KeystrokeBuffer.shared.clear()
            return
        }

        let isSpace = event.keyCode == 49
        let isReturn = [36, 76].contains(Int(event.keyCode))
        let delimiter = isSpace ? " " : (isReturn ? "\n" : nil)

        if let delimiter {
            let completedFromBuffer = KeystrokeBuffer.shared.onDelimiter(delimiter)
            if automaticRepair && !event.isARepeat {
                let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
                repairAutomatically(in: processID, completedWordFromBuffer: completedFromBuffer, delimiter: delimiter)
            }
            return
        }

        if let characters = event.characters, !characters.isEmpty {
            KeystrokeBuffer.shared.append(characters)
        }

        guard automaticRepair, !event.isARepeat else { return }

        // Pause check (~350ms) for multi-word phrases or completed words
        let expectedRevision = revision
        let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard let self, self.revision == expectedRevision,
                  NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
            self.repairPhraseOrCompletedWord(in: processID)
        }
    }

    private func handleFlags(_ event: NSEvent) {
        guard let modifier = doubleTap.flagsChanged(event.modifierFlags, at: event.timestamp) else { return }
        if case .doubleTap(let configured) = previousWordShortcut, configured == modifier {
            repairManually()
        }
    }

    private func repairManually() {
        let snapshot = FocusedText.read()
        let selected = snapshot.map { $0.selection.length > 0 } ?? false
        let input: String? = {
            if let snapshot {
                return selected ? snapshot.selectedText : WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: false)
            }
            let bufferWord = KeystrokeBuffer.shared.currentWord
            return bufferWord.isEmpty ? nil : bufferWord
        }()

        guard let input, let conversion = LayoutConversion.convert(input) else { return }

        var replaced = false
        if let snapshot, snapshot.isStillCurrent() {
            if selected {
                replaced = snapshot.replaceDirectly(
                    range: NSRange(location: snapshot.selection.location, length: snapshot.selection.length),
                    with: conversion.output
                )
            } else {
                let range = NSRange(location: snapshot.selection.location - input.utf16.count, length: input.utf16.count)
                replaced = snapshot.replaceDirectly(range: range, with: conversion.output)
            }
        }

        if !replaced {
            KeyboardReplacement.replace(backspaces: input.utf16.count, with: conversion.output)
        }

        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        statusText = "Repaired: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
        if playSound { soundPlayer.play() }
    }

    private func repairAutomatically(in processID: pid_t?, completedWordFromBuffer: String?, delimiter: String) {
        guard let processID, !ApplicationExclusions.contains(bundleID: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier) else { return }

        // 1. Preferred path: Accessible text field (TextEdit, Safari, Notes, Mail, etc.)
        if let snapshot = FocusedText.read(), snapshot.processID == processID, snapshot.selection.length == 0 {
            let candidateWord = WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: true) ?? completedWordFromBuffer
            guard let word = candidateWord, let conversion = DecisionEngine.candidate(for: word) else { return }

            let targetRange = NSRange(location: max(0, snapshot.selection.location - word.utf16.count - delimiter.utf16.count), length: word.utf16.count)

            // Try direct memory replacement
            if snapshot.replaceDirectly(range: targetRange, with: conversion.output) {
                keyboard.select(conversion.target)
                currentLayout = keyboard.currentLayout
                statusText = "Auto: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
                if playSound { soundPlayer.play() }
                return
            }

            // Fallback for fields where replaceDirectly fails (e.g. Electron apps, WebViews)
            KeyboardReplacement.replace(backspaces: word.utf16.count + delimiter.utf16.count, with: conversion.output + delimiter)
            keyboard.select(conversion.target)
            currentLayout = keyboard.currentLayout
            statusText = "Auto: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
            if playSound { soundPlayer.play() }
            return
        }

        // 2. Terminal / CLI / Non-accessible apps path (Terminal, iTerm2, Alacritty, Warp)
        guard let rawWord = completedWordFromBuffer, !rawWord.isEmpty else { return }
        let word = WordBoundary.extractFileExtension(from: rawWord) ?? rawWord
        guard let conversion = DecisionEngine.candidate(for: word) else { return }

        // In terminals, send backspaces for the word + delimiter, then type the converted word + delimiter
        KeyboardReplacement.replace(backspaces: word.utf16.count + delimiter.utf16.count, with: conversion.output + delimiter)
        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        statusText = "CLI Auto: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
        if playSound { soundPlayer.play() }
    }

    private func repairPhraseOrCompletedWord(in processID: pid_t?) {
        guard let processID, !ApplicationExclusions.contains(bundleID: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0 else { return }

        // Try whole-phrase repair first
        if let lastLine = snapshot.prefix.split(separator: "\n").last,
           let conversion = DecisionEngine.phraseCandidate(for: String(lastLine)),
           snapshot.selection.location >= lastLine.utf16.count {
            let range = NSRange(location: snapshot.selection.location - lastLine.utf16.count, length: lastLine.utf16.count)
            if snapshot.replaceDirectly(range: range, with: conversion.output) {
                keyboard.select(conversion.target)
                currentLayout = keyboard.currentLayout
                statusText = "Phrase: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
                if playSound { soundPlayer.play() }
                return
            }
        }

        // Try recent completed word repair
        for candidate in WordBoundary.recentCompletedWords(in: snapshot.prefix) {
            guard let conversion = DecisionEngine.candidate(for: candidate.word) else { continue }
            let location = snapshot.selection.location - candidate.trailing.utf16.count - candidate.word.utf16.count
            guard location >= 0 else { continue }
            let range = NSRange(location: location, length: candidate.word.utf16.count)
            if snapshot.replaceDirectly(range: range, with: conversion.output) {
                if candidate.trailing.count <= 1 {
                    keyboard.select(conversion.target)
                }
                currentLayout = keyboard.currentLayout
                statusText = "Auto: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
                if playSound { soundPlayer.play() }
                return
            }
        }
    }
}
