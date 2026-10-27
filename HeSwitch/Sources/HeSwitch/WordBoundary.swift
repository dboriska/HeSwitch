import Foundation

public enum WordBoundary {
    public static func isCompletionDelimiter(_ character: Character) -> Bool {
        character == " " || character == "\u{00A0}" || character == "\u{202F}" || character == "\n" || character == "\t"
    }

    /// Extracts recent completed words before the caret, allowing a trailing delimiter or punctuation.
    public static func recentCompletedWords(in prefix: String, maxTrailingCharacters: Int = 32) -> [(word: String, trailing: String)] {
        let characters = Array(prefix)
        guard !characters.isEmpty else { return [] }
        var result: [(word: String, trailing: String)] = []

        for index in characters.indices.reversed() {
            guard isCompletionDelimiter(characters[index]) else { continue }
            let trailing = String(characters[index...])
            guard trailing.count <= maxTrailingCharacters else { break }

            if let word = precedingWord(in: String(characters[...index]), allowDelimiter: true) {
                result.append((word, trailing))
            }
        }
        return result
    }

    /// Extracts the word immediately preceding the caret or delimiter.
    /// In Hebrew, punctuation like `,` (ת), `.` (ץ), `;` (ף), `'` (comma/geresh), and `"` (gershayim)
    /// can be integral parts of words.
    public static func precedingWord(in prefix: String, allowDelimiter: Bool) -> String? {
        var characters = Array(prefix)
        if allowDelimiter {
            guard let last = characters.last, isCompletionDelimiter(last) else { return nil }
            characters.removeLast()
        }

        // Include characters that can represent Hebrew letters or acronyms:
        // `,` is ת, `.` is ץ, `;` is ף, `'` is geresh, `"` is gershayim, `׳` is geresh, `״` is gershayim
        let word = String(characters.reversed().prefix { char in
            char.isLetter || (!char.isNumber && "`[];',.\"״׳’".contains(char))
        }.reversed())

        // Trim any trailing pure punctuation (e.g. trailing period from real punctuation)
        var trimmed = word
        while trimmed.hasSuffix(".") || trimmed.hasSuffix(",") || trimmed.hasSuffix(";") || trimmed.hasSuffix("!") || trimmed.hasSuffix("?") {
            // But don't trim if it is preceded by another letter and could be Hebrew Tav or Tsadi Sofit:
            // e.g. "t,v" or "ch," (בית) or "t," (את)
            // If the preceding char is a Hebrew letter, a trailing period is just a period!
            if let last = trimmed.last, last == "." || last == ",", let prev = trimmed.dropLast().last {
                if LayoutConversion.isHebrew(prev) {
                    trimmed.removeLast()
                    continue
                }
            }
            break
        }

        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }

        // Check for file extension with different script:
        // e.g. "README.צג" where base is English ("README") and extension is Hebrew ("צג")
        // In this case, only the extension "צג" should be repaired to "md"!
        if let dotIndex = trimmed.lastIndex(of: ".") {
            let ext = String(trimmed[trimmed.index(after: dotIndex)...])
            let base = String(trimmed[..<dotIndex])
            if !ext.isEmpty && ext.count <= 5 && !base.isEmpty {
                let extIsHebrew = ext.allSatisfy { LayoutConversion.isHebrew($0) }
                let baseIsEnglish = base.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }
                if extIsHebrew && baseIsEnglish {
                    return ext
                }
                let extIsEnglish = ext.allSatisfy { $0.isASCII && $0.isLetter }
                let baseIsHebrew = base.allSatisfy { LayoutConversion.isHebrew($0) }
                if extIsEnglish && baseIsHebrew {
                    return ext
                }
            }
        }

        // Ensure word is not part of a URL, email, or filesystem path
        if characters.count > trimmed.count {
            let precedingChar = characters[characters.count - trimmed.count - 1]
            if precedingChar == "/" || precedingChar == "@" || precedingChar == ":" || precedingChar == "\\" {
                return nil
            }
        }

        return trimmed
    }
}
