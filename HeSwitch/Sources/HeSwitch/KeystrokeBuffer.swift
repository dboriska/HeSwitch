import Foundation

@MainActor
public final class KeystrokeBuffer {
    public static let shared = KeystrokeBuffer()

    public private(set) var currentWord: String = ""
    public private(set) var lastCompletedWord: String = ""
    public private(set) var lastDelimiter: String = ""

    private init() {}

    public func append(_ chars: String) {
        // Only buffer if characters can be part of a word or Hebrew punctuation
        for ch in chars {
            if ch.isLetter || "`[];',.\"״׳-".contains(ch) {
                currentWord.append(ch)
            } else if WordBoundary.isCompletionDelimiter(ch) {
                _ = onDelimiter(String(ch))
            } else {
                // Symbols or spaces reset current word
                currentWord = ""
            }
        }
    }

    public func backspace() {
        if !currentWord.isEmpty {
            currentWord.removeLast()
        }
    }

    public func onDelimiter(_ delimiter: String) -> String? {
        let completed = currentWord
        lastCompletedWord = completed
        lastDelimiter = delimiter
        currentWord = ""
        return completed.isEmpty ? nil : completed
    }

    public func clear() {
        currentWord = ""
        lastCompletedWord = ""
        lastDelimiter = ""
    }
}
