import AppKit
import ApplicationServices
import Carbon

@MainActor
public struct FocusedText {
    private static var enabledAccessibilityPIDs = Set<pid_t>()

    public let element: AXUIElement
    public let processID: pid_t
    public let value: String
    public let selection: CFRange

    public static func read() -> Self? {
        guard AXIsProcessTrusted(),
              CGPreflightListenEventAccess(),
              !IsSecureEventInputEnabled(),
              let processID = NSWorkspace.shared.frontmostApplication?.processIdentifier,
              processID != ProcessInfo.processInfo.processIdentifier else { return nil }

        let app = AXUIElementCreateApplication(processID)
        AXUIElementSetMessagingTimeout(app, 0.1)

        // Enable accessibility for Electron/Chromium apps if dormant
        if enabledAccessibilityPIDs.insert(processID).inserted {
            AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
        }

        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() else { return nil }

        let element = focused as! AXUIElement
        AXUIElementSetMessagingTimeout(element, 0.1)

        var subrole: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subrole) == .success,
           let subrole = subrole as? String,
           subrole == kAXSecureTextFieldSubrole as String {
            return nil
        }

        var valueRef: CFTypeRef?
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef) == .success,
              let value = valueRef as? String,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef, CFGetTypeID(rangeRef) == AXValueGetTypeID() else { return nil }

        var selection = CFRange(location: 0, length: 0)
        guard AXValueGetValue(rangeRef as! AXValue, .cfRange, &selection),
              selection.location >= 0, selection.length >= 0,
              selection.location + selection.length <= (value as NSString).length else { return nil }

        return Self(element: element, processID: processID, value: value, selection: selection)
    }

    public func isStillCurrent() -> Bool {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID,
              let current = Self.read() else { return false }
        return CFEqual(element, current.element)
            && selection.location == current.selection.location
            && selection.length == current.selection.length
            && value == current.value
    }

    public func replaceDirectly(range: NSRange, with replacement: String) -> Bool {
        guard selection.length == 0,
              range.location >= 0, range.length > 0,
              range.location + range.length <= (value as NSString).length,
              isStillCurrent() else { return false }

        var rangeSettable = DarwinBoolean(false)
        var textSettable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &rangeSettable) == .success,
              rangeSettable.boolValue else { return false }

        let canReplaceSelection = AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString, &textSettable) == .success
            && textSettable.boolValue

        let expectedValue = (value as NSString).replacingCharacters(in: range, with: replacement)
        var result: AXError = .attributeUnsupported

        if canReplaceSelection {
            var selectedRange = CFRange(location: range.location, length: range.length)
            guard let selectedValue = AXValueCreate(.cfRange, &selectedRange),
                  AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selectedValue) == .success else {
                return false
            }
            result = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, replacement as CFString)
        }

        if result != .success, (value as NSString).length <= 2048 {
            var valueSettable = DarwinBoolean(false)
            if AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &valueSettable) == .success,
               valueSettable.boolValue {
                result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, expectedValue as CFString)
            }
        }

        let delta = (replacement as NSString).length - range.length
        var restoredCaret = CFRange(location: selection.location + (result == .success ? delta : 0), length: 0)
        guard let caretValue = AXValueCreate(.cfRange, &restoredCaret),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue) == .success else {
            return false
        }

        guard result == .success else { return false }

        var actualValueRef: CFTypeRef?
        var actualRangeRef: CFTypeRef?
        var verifiedCaret = CFRange(location: 0, length: 0)

        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &actualValueRef) == .success,
              let actualValue = actualValueRef as? String,
              actualValue == expectedValue,
              AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &actualRangeRef) == .success,
              let actualRangeRef, CFGetTypeID(actualRangeRef) == AXValueGetTypeID(),
              AXValueGetValue(actualRangeRef as! AXValue, .cfRange, &verifiedCaret),
              verifiedCaret.location == restoredCaret.location,
              verifiedCaret.length == 0 else { return false }

        return true
    }

    public func selectForPaste(range: NSRange) -> Bool {
        guard selection.length == 0,
              range.location >= 0, range.length > 0,
              range.location + range.length <= (value as NSString).length,
              isStillCurrent() else { return false }

        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextRangeAttribute as CFString, &settable) == .success,
              settable.boolValue else { return false }

        var selectedRange = CFRange(location: range.location, length: range.length)
        guard let selectedValue = AXValueCreate(.cfRange, &selectedRange),
              AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, selectedValue) == .success else {
            return false
        }

        var currentRangeRef: CFTypeRef?
        var confirmedRange = CFRange(location: 0, length: 0)
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &currentRangeRef) == .success,
              let currentRangeRef, CFGetTypeID(currentRangeRef) == AXValueGetTypeID(),
              AXValueGetValue(currentRangeRef as! AXValue, .cfRange, &confirmedRange),
              confirmedRange.location == range.location,
              confirmedRange.length == range.length else {
            restoreCaretIfUnchanged()
            return false
        }

        return true
    }

    public func restoreCaretIfUnchanged() {
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == processID else { return }
        var actualValueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &actualValueRef) == .success,
              let actualValue = actualValueRef as? String, actualValue == value else { return }
        var caret = CFRange(location: selection.location, length: 0)
        if let caretValue = AXValueCreate(.cfRange, &caret) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
    }

    public var prefix: String {
        (value as NSString).substring(to: selection.location)
    }

    public var selectedText: String {
        (value as NSString).substring(with: NSRange(location: selection.location, length: selection.length))
    }
}
