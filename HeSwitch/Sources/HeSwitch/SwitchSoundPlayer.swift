import AppKit
import AudioToolbox

@MainActor
public final class SwitchSoundPlayer {
    public init() {}

    public func play() {
        // macOS standard system click/tick sound
        AudioServicesPlaySystemSound(1104) // Tink sound
    }
}
