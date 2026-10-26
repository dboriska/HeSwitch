import AppKit

public struct KeyChord: Codable, Equatable {
    public let keyCode: UInt16
    public let modifiers: UInt

    public static let modifierMask: CGEventFlags = [.maskCommand, .maskShift, .maskControl, .maskAlternate]

    public init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public func matches(_ event: CGEvent) -> Bool {
        guard UInt16(event.getIntegerValueField(.keyboardEventKeycode)) == keyCode else { return false }
        let current = event.flags.intersection(Self.modifierMask).rawValue
        return current == modifiers
    }

    public static func capture(_ event: NSEvent) -> KeyChord? {
        let flags = CGEventFlags(rawValue: UInt64(event.modifierFlags.rawValue)).intersection(modifierMask)
        guard !flags.isEmpty else { return nil }
        return KeyChord(keyCode: event.keyCode, modifiers: UInt(flags.rawValue))
    }
}

public enum ManualAction: String, Codable {
    case previousWord = "previousWord"
    case selection = "selection"
}

public enum ManualShortcut: Codable, Equatable {
    case doubleTap(DoubleTapModifier)
    case chord(KeyChord)

    public var title: String {
        switch self {
        case .doubleTap(let mod):
            return "Double \(mod.rawValue)"
        case .chord(let chord):
            return "Key \(chord.keyCode)"
        }
    }
}

@MainActor
public final class ShortcutEventTap {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var chords: [KeyChord] = []
    private var pending: (chord: KeyChord, processID: pid_t)?
    private let onChord: @MainActor (KeyChord) -> Void

    public init(onChord: @escaping @MainActor (KeyChord) -> Void) {
        self.onChord = onChord
    }

    public func update(chords: [KeyChord]) -> Bool {
        if !chords.isEmpty && !ensureActive() { return false }
        self.chords = chords
        pending = nil
        if chords.isEmpty, let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        return true
    }

    private func ensureActive() -> Bool {
        if let tap {
            if !CGEvent.tapIsEnabled(tap: tap) { CGEvent.tapEnable(tap: tap, enable: true) }
            return CGEvent.tapIsEnabled(tap: tap)
        }
        let mask = (CGEventMask(1) << CGEventType.keyDown.rawValue)
            | (CGEventMask(1) << CGEventType.keyUp.rawValue)
            | (CGEventMask(1) << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let manager = Unmanaged<ShortcutEventTap>.fromOpaque(userInfo).takeUnretainedValue()
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    MainActor.assumeIsolated { manager.reenable() }
                    return Unmanaged.passUnretained(event)
                }
                let consumed = MainActor.assumeIsolated { manager.handle(type, event) }
                return consumed ? nil : Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else { return false }
        self.tap = tap
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return CGEvent.tapIsEnabled(tap: tap)
    }

    private func reenable() {
        pending = nil
        if !chords.isEmpty, let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }

    private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard event.getIntegerValueField(.eventSourceUserData) != KeyboardReplacement.eventTag else { return false }

        if type == .flagsChanged {
            if let pending, event.flags.intersection(KeyChord.modifierMask).isEmpty {
                self.pending = nil
                if NSWorkspace.shared.frontmostApplication?.processIdentifier == pending.processID {
                    DispatchQueue.main.async { [weak self] in self?.onChord(pending.chord) }
                }
            }
            return false
        }

        if type == .keyUp {
            return pending?.chord.keyCode == UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        }

        guard type == .keyDown,
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              processID != ProcessInfo.processInfo.processIdentifier else { return false }

        guard let chord = chords.first(where: { $0.matches(event) }) else {
            pending = nil
            return false
        }

        pending = (chord, processID)
        return true
    }
}
