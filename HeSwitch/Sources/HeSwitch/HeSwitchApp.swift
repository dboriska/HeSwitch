import AppKit
import ApplicationServices
import ServiceManagement
import SwiftUI

@main
struct HeSwitchApp: App {
    @StateObject private var model = HeSwitchModel.shared
    @Environment(\.openSettings) private var openSettings

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
                    Text("Accessibility & Input Monitoring permissions are required.")
                        .font(.caption)
                        .foregroundColor(.red)
                    Button("Grant Permissions…") {
                        model.requestPermissions()
                    }
                }

                Divider()

                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
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

    public var hasRequiredAccess: Bool { hasAccessibilityAccess && hasInputMonitoringAccess }

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

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in self?.handleKey(event) }
        }

        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            Task { @MainActor in self?.handleFlags(event) }
        }

        layoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentLayout = self?.keyboard.currentLayout
            }
        }

        accessTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
            }
        }
    }

    public func refreshPermissions() {
        hasAccessibilityAccess = AXIsProcessTrusted()
        hasInputMonitoringAccess = CGPreflightListenEventAccess()
    }

    public func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt" as CFString: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        CGRequestListenEventAccess()
        refreshPermissions()
    }

    public func refreshLaunchAtLogin() {
        let state = SMAppService.mainApp.status
        launchAtLogin = state == .enabled || state == .requiresApproval
    }

    public func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshLaunchAtLogin()
        } catch {
            refreshLaunchAtLogin()
        }
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

        guard automaticRepair, !event.isARepeat else { return }

        let expectedRevision = revision
        let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // 1. Immediate check on word delimiters (Space 49, Return 36, Enter 76)
        if [49, 36, 76].contains(Int(event.keyCode)) {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(35))
                guard self.revision == expectedRevision,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
                self.repairAutomatically(in: processID)
            }
        }

        // 2. Pause check (~350ms) for completed word or phrase
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(350))
            guard self.revision == expectedRevision,
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
        guard let snapshot = FocusedText.read() else { return }
        let selected = snapshot.selection.length > 0
        let input = selected ? snapshot.selectedText : WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: false)

        guard let input, let conversion = LayoutConversion.convert(input), snapshot.isStillCurrent() else { return }

        if selected {
            _ = snapshot.replaceDirectly(range: NSRange(location: snapshot.selection.location, length: snapshot.selection.length), with: conversion.output)
        } else {
            let range = NSRange(location: snapshot.selection.location - input.utf16.count, length: input.utf16.count)
            if !snapshot.replaceDirectly(range: range, with: conversion.output) {
                KeyboardReplacement.replace(backspaces: input.utf16.count, with: conversion.output)
            }
        }

        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        statusText = "Repaired: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
        if playSound { soundPlayer.play() }
    }

    private func repairAutomatically(in processID: pid_t?) {
        guard let processID, !ApplicationExclusions.contains(bundleID: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0,
              let delimiter = snapshot.prefix.last, WordBoundary.isCompletionDelimiter(delimiter),
              let word = WordBoundary.precedingWord(in: snapshot.prefix, allowDelimiter: true),
              let conversion = DecisionEngine.candidate(for: word),
              snapshot.selection.location >= word.utf16.count + 1 else { return }

        let range = NSRange(location: snapshot.selection.location - word.utf16.count - 1, length: word.utf16.count)
        guard snapshot.replaceDirectly(range: range, with: conversion.output) else { return }

        keyboard.select(conversion.target)
        currentLayout = keyboard.currentLayout
        statusText = "Auto: \(conversion.source.rawValue) → \(conversion.target.rawValue)"
        if playSound { soundPlayer.play() }
    }

    private func repairPhraseOrCompletedWord(in processID: pid_t?) {
        guard let processID, !ApplicationExclusions.contains(bundleID: NSRunningApplication(processIdentifier: processID)?.bundleIdentifier),
              let snapshot = FocusedText.read(), snapshot.processID == processID,
              snapshot.selection.length == 0 else { return }

        // Try phrase repair first
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
