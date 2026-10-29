import AppKit

@MainActor
public enum DecisionEngine {
    public enum ScriptContext {
        case hebrew
        case english
        case neutral
    }

    public nonisolated static func scriptOfContext(_ context: String?) -> ScriptContext {
        guard let context = context, !context.isEmpty else { return .neutral }
        let lastLine = context.components(separatedBy: .newlines).last ?? context
        let trimmed = lastLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .neutral }

        var hebrewCount = 0
        var englishCount = 0

        for scalar in trimmed.unicodeScalars {
            if (0x0590...0x05FF).contains(scalar.value) || scalar.value == 0x05F3 || scalar.value == 0x05F4 {
                hebrewCount += 1
            } else if (0x0041...0x005A).contains(scalar.value) || (0x0061...0x007A).contains(scalar.value) {
                englishCount += 1
            }
        }

        if hebrewCount > englishCount {
            return .hebrew
        } else if englishCount > hebrewCount {
            return .english
        } else {
            return .neutral
        }
    }

    public nonisolated static func isCliCommandContext(_ context: String?) -> Bool {
        guard let context = context else { return false }
        let lastLine = context.components(separatedBy: .newlines).last ?? context
        let tokens = lastLine.split { $0.isWhitespace }.map(String.init)
        guard let firstToken = tokens.first?.lowercased() else { return false }
        let cliCommands: Set<String> = [
            "cat", "vim", "vi", "nano", "touch", "code", "open", "less", "more",
            "head", "tail", "echo", "grep", "mv", "cp", "rm", "git", "ls"
        ]
        return cliCommands.contains(firstToken)
    }

    public static func candidate(for word: String, context: String? = nil, isTerminalApp: Bool = false) -> Conversion? {
        let lower = word.lowercased()
        guard word.count >= 2, word.count <= 40,
              !CustomDictionary.contains(word),
              lower != HeSwitchModel.shared.temporarilySuppressedWord,
              let conversion = LayoutConversion.convert(word),
              !ExcludedWords.isExcluded(word, language: conversion.source),
              !ExcludedWords.isExcluded(conversion.output, language: conversion.target) else { return nil }

        // Converted word must be mostly letters or legitimate Hebrew punctuation (geresh, gershayim, hyphen)
        let isValidTargetChars = conversion.output.allSatisfy { char in
            char.isLetter || "\"'״׳-".contains(char)
        }
        guard isValidTargetChars else { return nil }

        let targetLower = conversion.output.lowercased()

        // Check if capitalized English transcoding is disabled
        let isMixedScript = (word.unicodeScalars.contains { (0x0041...0x005A).contains($0.value) || (0x0061...0x007A).contains($0.value) } || word.hasPrefix("\"") || word.hasPrefix("״")) &&
                            word.unicodeScalars.contains { (0x0590...0x05FF).contains($0.value) || $0.value == 0x05F3 || $0.value == 0x05F4 }
        if isMixedScript && !HeSwitchModel.shared.convertCapitalizedEnglish {
            return nil
        }

        // --- Dual-Language Ambiguous Collision & Line Context Script Coherence ---
        let isAmbiguous = AmbiguousCollisions.isAmbiguousCollision(word) ||
                          AmbiguousCollisions.isAmbiguousCollision(conversion.output)

        if isAmbiguous {
            // Special rule: Markdown file extension or CLI command for 'צג' -> 'md'
            if lower == "צג" {
                if context?.hasSuffix(".") == true || word.hasPrefix(".") || isCliCommandContext(context) || isTerminalApp {
                    return conversion
                }
            }

            // Special rule for 'kph' <-> 'לפי':
            // 'לפי' is an exceptionally common Hebrew word ("according to", "by") and frequent sentence starter.
            // In English, 'kph' (kilometers per hour) is only used after a number (e.g. "100 kph") or in English context.
            if lower == "kph" {
                let lineScript = scriptOfContext(context)
                if lineScript == .english {
                    return nil
                }
                let trimmed = context?.trimmingCharacters(in: .whitespaces) ?? ""
                if let lastToken = trimmed.split(whereSeparator: { $0.isWhitespace }).last,
                   lastToken.contains(where: { $0.isNumber }) {
                    return nil
                }
                return conversion
            }

            let lineScript = scriptOfContext(context)
            switch lineScript {
            case .hebrew:
                // Preceding line context is Hebrew: continue on Hebrew without changing!
                if conversion.source == .english {
                    // Accidental English typing in a Hebrew sentence (e.g. "שלום, tbh" -> "אני", "קניתי md" -> "צג", "רוצה to" -> "אם")
                    return conversion
                } else {
                    // Word was typed in Hebrew in a Hebrew sentence (e.g. "קניתי צג", "אני פה", "אם תרצה") -> Keep in Hebrew!
                    return nil
                }
            case .english:
                // Preceding line context is English: continue on English without changing!
                if conversion.source == .hebrew {
                    // Accidental Hebrew typing in an English sentence (e.g. "I think אני" -> "tbh", "check צג" -> "md", "want אם" -> "to")
                    return conversion
                } else {
                    // Word was typed in English in an English sentence (e.g. "tbh I agree", "I want to go") -> Keep in English!
                    return nil
                }
            case .neutral:
                // Standalone / first word of line with no script context:
                // Keep the typed language to prevent false positives in isolation!
                return nil
            }
        }

        let checker = NSSpellChecker.shared
        let sourceLang = language(for: conversion.source, available: checker.availableLanguages)
        let targetLang = language(for: conversion.target, available: checker.availableLanguages)

        let sourceIsCorrect = isCorrect(lower, language: sourceLang, checker: checker)
        let containsHebrewPunctuationKeys = word.contains(where: { ",.;'".contains($0) })

        // 1. English words that are already correctly spelled without Hebrew punctuation keys must NEVER be converted!
        if conversion.source == .english && sourceIsCorrect && !containsHebrewPunctuationKeys {
            return nil
        }

        // 2. High-frequency vocabulary fast-path:
        // Common words (e.g. "and" [שמג], "what" [׳ישא], "how" [ים׳], "the", "you", "shalom")
        // take priority over morphological ambiguities in Hebrew.
        if HighFrequencyVocabulary.isHighFrequency(targetLower, language: conversion.target) {
            return conversion
        }

        // 3. Custom dictionary check:
        if CustomDictionary.contains(conversion.output) {
            return conversion
        }

        // 4. If Hebrew source was already correct and not containing punctuation keys:
        if sourceIsCorrect && !containsHebrewPunctuationKeys {
            return nil
        }

        // 5. Check if the converted word is correct in the target language
        // (Checks both lowercased target and original case to properly accept capitalized proper nouns like Israel, Google)
        let targetIsCorrect = isCorrect(targetLower, language: targetLang, checker: checker) ||
                              isCorrect(conversion.output, language: targetLang, checker: checker)
        guard targetIsCorrect else { return nil }

        return conversion
    }

    /// Evaluates if an entire line/phrase typed in the wrong layout should be repaired
    public static func phraseCandidate(for phrase: String) -> Conversion? {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4, trimmed.count <= 120 else { return nil }

        let tokens = trimmed.split(separator: " ").map(String.init)
        guard tokens.count >= 2 else { return nil }

        var convertedTokens: [String] = []
        var repairCount = 0

        for (index, token) in tokens.enumerated() {
            let preceding = tokens[..<index].joined(separator: " ")
            if let conv = candidate(for: token, context: preceding.isEmpty ? phrase : preceding) {
                convertedTokens.append(conv.output)
                repairCount += 1
            } else if let conv = LayoutConversion.convert(token) {
                convertedTokens.append(conv.output)
            } else {
                convertedTokens.append(token)
            }
        }

        // At least 1 clear repair and more than 40% of the phrase should match
        guard repairCount >= 1, Double(repairCount) / Double(tokens.count) >= 0.4 else {
            return nil
        }

        guard let firstConversion = LayoutConversion.convert(trimmed) else { return nil }
        return Conversion(
            input: trimmed,
            output: convertedTokens.joined(separator: " "),
            source: firstConversion.source,
            target: firstConversion.target
        )
    }

    private static func language(for layout: KeyboardLanguage, available: [String]) -> String {
        switch layout {
        case .english:
            return available.first { $0.lowercased().hasPrefix("en") } ?? "en_US"
        case .hebrew:
            return available.first { $0.lowercased().hasPrefix("he") || $0.lowercased().hasPrefix("iw") } ?? "he_IL"
        }
    }

    private static func isCorrect(_ word: String, language: String, checker: NSSpellChecker) -> Bool {
        checker.checkSpelling(
            of: word,
            startingAt: 0,
            language: language,
            wrap: false,
            inSpellDocumentWithTag: 0,
            wordCount: nil
        ).location == NSNotFound
    }
}
