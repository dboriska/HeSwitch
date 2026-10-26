import Carbon
import Foundation

@MainActor
public final class KeyboardLayoutService {
    public init() {}

    public var currentLayout: KeyboardLanguage? {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        return layout(for: source)
    }

    public func select(_ target: KeyboardLanguage) {
        guard let sources = TISCreateInputSourceList(nil, false)?.takeRetainedValue() as? [TISInputSource],
              let source = sources.first(where: { layout(for: $0) == target }) else { return }
        TISSelectInputSource(source)
    }

    private func layout(for source: TISInputSource) -> KeyboardLanguage? {
        // 1. Check by language tag
        if let langPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceLanguages) {
            let languages = Unmanaged<CFArray>.fromOpaque(langPtr).takeUnretainedValue() as? [String] ?? []
            if languages.contains(where: { $0.lowercased().hasPrefix("he") || $0.lowercased().hasPrefix("iw") }) {
                return .hebrew
            }
            if languages.contains(where: { $0.lowercased().hasPrefix("en") }) {
                return .english
            }
        }

        // 2. Fallback check by Input Source ID
        if let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) {
            let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
            let lowerID = sourceID.lowercased()
            if lowerID.contains("hebrew") {
                return .hebrew
            }
            if lowerID.contains(".us") || lowerID.contains(".abc") || lowerID.contains("british") || lowerID.contains("english") {
                return .english
            }
        }

        return nil
    }
}
