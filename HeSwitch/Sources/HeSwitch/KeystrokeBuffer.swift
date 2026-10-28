import Foundation

@MainActor
public final class KeystrokeBuffer {
    public static let shared = KeystrokeBuffer()

    public private(set) var currentWord: String = ""
    public private(set) var lastCompletedWord: String = ""
    public private(set) var lastDelimiter: String = ""
    public private(set) var lineContext: String = ""

    private init() {}

    public func append(_ chars: String) {
        // Only buffer if characters can be part of a word or Hebrew punctuation
        for ch in chars {
            if ch == "\n" || ch == "\r" {
                currentWord = ""
                lineContext = ""
            } else if ch.isLetter || "`[];',.\"״׳-".contains(ch) {
                currentWord.append(ch)
            } else if WordBoundary.isCompletionDelimiter(ch) {
                _ = onDelimiter(String(ch))
            } else {
                // Other symbols or characters
                currentWord = ""
                lineContext.append(ch)
            }
        }
    }

    public func backspace() {
        if !currentWord.isEmpty {
            currentWord.removeLast()
        } else if !lineContext.isEmpty {
            lineContext.removeLast()
        }
    }

    public func onDelimiter(_ delimiter: String) -> String? {
        let completed = currentWord
        lastCompletedWord = completed
        lastDelimiter = delimiter
        if !completed.isEmpty {
            lineContext.append(completed)
            lineContext.append(delimiter)
            if lineContext.count > 256 {
                lineContext = String(lineContext.suffix(256))
            }
        }
        currentWord = ""
        return completed.isEmpty ? nil : completed
    }

    public func clear() {
        currentWord = ""
        lastCompletedWord = ""
        lastDelimiter = ""
        lineContext = ""
    }
}
