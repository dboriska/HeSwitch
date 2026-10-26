import AppKit

@MainActor
public enum KeyboardReplacement {
    public static let eventTag: Int64 = 0x48655377 // "HeSw"

    public static func replace(backspaces: Int, with text: String) {
        guard backspaces >= 0, backspaces <= 128, text.utf16.count <= 128 else { return }

        // Send backspaces
        for _ in 0..<backspaces {
            postKey(0x33)
        }

        // Post Unicode string directly
        let units = Array(text.utf16)
        units.withUnsafeBufferPointer { buffer in
            guard let pointer = buffer.baseAddress else { return }
            for down in [true, false] {
                guard let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: down) else { continue }
                event.flags = []
                event.setIntegerValueField(.eventSourceUserData, value: eventTag)
                event.keyboardSetUnicodeString(stringLength: units.count, unicodeString: pointer)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    public static func postKey(_ code: CGKeyCode, flags: CGEventFlags = []) {
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: nil, virtualKey: code, keyDown: down) else { continue }
            event.flags = flags
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cghidEventTap)
        }
    }

    public static func paste(_ text: String) -> ClipboardRestore? {
        let pasteboard = NSPasteboard.general
        let savedItems = pasteboard.pasteboardItems?.compactMap { original -> NSPasteboardItem? in
            let copy = NSPasteboardItem()
            for type in original.types {
                if let data = original.data(forType: type) { copy.setData(data, forType: type) }
            }
            return copy.types.isEmpty ? nil : copy
        } ?? []

        pasteboard.clearContents()
        guard pasteboard.setString(text, forType: .string) else {
            pasteboard.clearContents()
            if !savedItems.isEmpty { pasteboard.writeObjects(savedItems) }
            return nil
        }

        let changeCount = pasteboard.changeCount
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: down) else { // 'v' key
                return ClipboardRestore(items: savedItems, changeCount: changeCount)
            }
            event.flags = .maskCommand
            event.setIntegerValueField(.eventSourceUserData, value: eventTag)
            event.post(tap: .cgAnnotatedSessionEventTap)
        }
        return ClipboardRestore(items: savedItems, changeCount: changeCount)
    }
}

public struct ClipboardRestore {
    public let items: [NSPasteboardItem]
    public let changeCount: Int

    public func restoreIfUnchanged() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount == changeCount else { return }
        pasteboard.clearContents()
        if !items.isEmpty { pasteboard.writeObjects(items) }
    }
}
