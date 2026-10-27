import Foundation

public enum KeyboardLanguage: String, Codable {
    case english = "EN"
    case hebrew = "HE"

    public var opposite: Self { self == .english ? .hebrew : .english }
}

public struct Conversion: Equatable {
    public let input: String
    public let output: String
    public let source: KeyboardLanguage
    public let target: KeyboardLanguage

    public init(input: String, output: String, source: KeyboardLanguage, target: KeyboardLanguage) {
        self.input = input
        self.output = output
        self.source = source
        self.target = target
    }
}

public enum LayoutConversion {
    // Standard English QWERTY
    private static let englishBase = Array("`1234567890-=qwertyuiop[]\\asdfghjkl;'zxcvbnm,./")
    // Standard Hebrew (SI-1452 / macOS Hebrew Layout)
    private static let hebrewBase  = Array(";1234567890-=/'קראטוןםפ][\\שדגכעיחלךף,זסבהנמצתץ.")

    public static let enToHe: [Character: Character] = {
        var map = Dictionary(uniqueKeysWithValues: zip(englishBase, hebrewBase))
        // Hebrew has no uppercase letters; map uppercase English letters to same Hebrew keys
        for (e, h) in zip(englishBase, hebrewBase) where e.isLetter {
            if let upper = Character(String(e).uppercased()).unicodeScalars.first {
                map[Character(upper)] = h
            }
        }
        // In macOS Hebrew layout, the physical W key corresponds to Hebrew Geresh (׳ U+05F3)
        map["w"] = "׳"
        map["W"] = "׳"
        return map
    }()

    public static let heToEn: [Character: Character] = {
        var map = Dictionary(uniqueKeysWithValues: zip(hebrewBase, englishBase))
        // On macOS Hebrew layout, physical W produces '׳' (U+05F3) or '\'' or '’'
        map["׳"] = "w"
        map["'"] = "w"
        map["’"] = "w"
        return map
    }()

    /// Detects source language and converts text to the opposite layout.
    /// Returns nil if string contains mixed scripts or no convertible characters.
    public static func convert(_ text: String) -> Conversion? {
        guard !text.isEmpty else { return nil }

        // 1. Fast-path for English words typed with Hebrew Geresh or apostrophe for 'w':
        // e.g. "׳hat" -> "what", "ho׳" -> "how", "׳orld" -> "world", "׳hen" -> "when", "to׳er" -> "tower"
        if text.contains("׳") || text.contains("’") || text.contains("'") {
            let lower = text.lowercased()
            let commonContractions: Set<String> = [
                "don't", "can't", "won't", "it's", "i'm", "you're", "they're", "we're",
                "that's", "what's", "there's", "he's", "she's", "let's", "didn't",
                "doesn't", "isn't", "aren't", "wasn't", "weren't", "haven't", "hasn't",
                "hadn't", "couldn't", "shouldn't", "wouldn't"
            ]
            if !commonContractions.contains(lower) {
                let replaced = String(text.map { ($0 == "׳" || $0 == "’" || $0 == "'") ? "w" : $0 })
                if replaced != text && replaced.allSatisfy({ $0.isASCII && $0.isLetter }) {
                    return Conversion(
                        input: text,
                        output: replaced,
                        source: .hebrew,
                        target: .english
                    )
                }
            }
        }

        var enLetterCount = 0
        var heLetterCount = 0

        for scalar in text.unicodeScalars {
            if (0x0041...0x005A).contains(scalar.value) || (0x0061...0x007A).contains(scalar.value) {
                enLetterCount += 1
            } else if (0x0590...0x05FF).contains(scalar.value) {
                heLetterCount += 1
            }
        }

        // Cannot reliably convert mixed-script words
        guard (enLetterCount > 0 && heLetterCount == 0) || (heLetterCount > 0 && enLetterCount == 0) else {
            return nil
        }

        let source: KeyboardLanguage = enLetterCount > 0 ? .english : .hebrew
        let map = source == .english ? enToHe : heToEn

        var converted = ""
        converted.reserveCapacity(text.count)

        let characters = Array(text)
        for i in 0..<characters.count {
            let current = characters[i]

            // Guard against decimal/thousands separators: "3.14" or "1,000"
            if (current == "." || current == ",") && i > 0 && i < characters.count - 1 {
                let prev = characters[i - 1]
                let next = characters[i + 1]
                if prev.isNumber && next.isNumber {
                    converted.append(current)
                    continue
                }
            }

            // In English typing, an apostrophe following a letter represents a Hebrew Geresh (e.g. m'hpx -> צ'יפס)
            if source == .english && current == "'" && i > 0 && characters[i - 1].isLetter {
                converted.append("'")
                continue
            }

            // Gershayim inside Hebrew words when converting English to Hebrew
            if source == .english && (current == "\"" || current == "״") {
                converted.append(current)
                continue
            }

            converted.append(map[current] ?? current)
        }

        guard converted != text else { return nil }

        return Conversion(
            input: text,
            output: converted,
            source: source,
            target: source.opposite
        )
    }

    /// Checks if a character is within the Hebrew Unicode block
    public static func isHebrew(_ char: Character) -> Bool {
        char.unicodeScalars.contains { (0x0590...0x05FF).contains($0.value) }
    }
}
