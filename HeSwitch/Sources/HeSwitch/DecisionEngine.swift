import AppKit

@MainActor
public enum DecisionEngine {
    public static func candidate(for word: String) -> Conversion? {
        let lower = word.lowercased()
        guard word.count >= 2, word.count <= 40,
              !CustomDictionary.contains(word),
              !AmbiguousCollisions.isAmbiguousCollision(word),
              lower != HeSwitchModel.shared.temporarilySuppressedWord,
              let conversion = LayoutConversion.convert(word) else { return nil }

        // Converted word must be mostly letters or legitimate Hebrew punctuation (geresh, gershayim)
        let isValidTargetChars = conversion.output.allSatisfy { char in
            char.isLetter || "\"'״׳".contains(char)
        }
        guard isValidTargetChars else { return nil }

        let targetLower = conversion.output.lowercased()

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
        let targetIsCorrect = isCorrect(targetLower, language: targetLang, checker: checker)
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

        for token in tokens {
            if let conv = candidate(for: token) {
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
