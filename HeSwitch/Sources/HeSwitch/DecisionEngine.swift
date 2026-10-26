import AppKit

@MainActor
public enum DecisionEngine {
    public static func candidate(for word: String) -> Conversion? {
        let lower = word.lowercased()
        guard word.count >= 2, word.count <= 40,
              !CustomDictionary.contains(word),
              !AmbiguousCollisions.isAmbiguousCollision(word),
              let conversion = LayoutConversion.convert(word) else { return nil }

        // Converted word must be mostly letters or legitimate Hebrew punctuation (geresh, gershayim)
        let isValidTargetChars = conversion.output.allSatisfy { char in
            char.isLetter || "\"'״׳".contains(char)
        }
        guard isValidTargetChars else { return nil }

        let checker = NSSpellChecker.shared
        guard let sourceLang = language(for: conversion.source, available: checker.availableLanguages),
              let targetLang = language(for: conversion.target, available: checker.availableLanguages) else {
            return nil
        }

        // Check if the original word was already correct in the source language
        let sourceIsCorrect = isCorrect(lower, language: sourceLang, checker: checker)
        
        // If the word contains punctuation characters that act as Hebrew letters (e.g. "t,v" or "ch,"),
        // it cannot be a real English word even if NSSpellChecker somehow didn't catch it.
        let containsHebrewPunctuationKeys = word.contains(where: { ",.;'".contains($0) })

        if sourceIsCorrect && !containsHebrewPunctuationKeys {
            return nil
        }

        // Verify that the converted word is recognized in the target language
        let targetLower = conversion.output.lowercased()
        let targetIsCorrect = CustomDictionary.contains(conversion.output)
            || isCorrect(targetLower, language: targetLang, checker: checker)

        guard targetIsCorrect else { return nil }

        return conversion
    }

    /// Evaluates if an entire line/phrase typed in the wrong layout should be repaired
    public static func phraseCandidate(for phrase: String) -> Conversion? {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 6, trimmed.count <= 120 else { return nil }

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

        // At least 2 words and more than half the phrase must be clearly wrong-layout tokens
        guard repairCount >= 2, Double(repairCount) / Double(tokens.count) >= 0.5 else {
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

    private static func language(for layout: KeyboardLanguage, available: [String]) -> String? {
        switch layout {
        case .english:
            return available.first { $0.lowercased().hasPrefix("en") }
        case .hebrew:
            // macOS supports Hebrew under "he" or legacy ISO code "iw"
            return available.first { $0.lowercased().hasPrefix("he") || $0.lowercased().hasPrefix("iw") }
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
