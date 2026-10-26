import AppKit

public enum DoubleTapModifier: String, Codable, CaseIterable {
    case shift = "Shift"
    case control = "Control"
    case option = "Option"
    case command = "Command"

    public var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .control: return .control
        case .option: return .option
        case .command: return .command
        }
    }
}

public struct DoubleTapDetector {
    private var lastModifier: DoubleTapModifier?
    private var lastTimestamp: TimeInterval = 0
    private var isDown = false

    public init() {}

    public mutating func flagsChanged(_ flags: NSEvent.ModifierFlags, at timestamp: TimeInterval) -> DoubleTapModifier? {
        let matching = DoubleTapModifier.allCases.first { modifier in
            flags.contains(modifier.flag)
        }

        if let matching {
            if !isDown {
                isDown = true
                if lastModifier == matching && (timestamp - lastTimestamp) <= 0.35 {
                    lastModifier = nil
                    lastTimestamp = 0
                    return matching
                }
                lastModifier = matching
                lastTimestamp = timestamp
            }
        } else {
            isDown = false
        }
        return nil
    }

    public mutating func keyPressed() {
        lastModifier = nil
        lastTimestamp = 0
        isDown = false
    }
}
