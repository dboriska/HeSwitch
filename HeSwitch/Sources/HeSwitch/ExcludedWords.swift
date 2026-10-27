import Foundation

public enum ExcludedWords {
    private static let key = "excludedWordsList"

    public static let defaultExcludedWords: [String] = [
        "ls", "cd", "rm", "cp", "mv", "ps", "df", "du", "vi", "sh", "id"
    ]

    public static var words: [String] {
        if let stored = UserDefaults.standard.stringArray(forKey: key) {
            return stored
        }
        return defaultExcludedWords
    }

    public static func contains(_ word: String) -> Bool {
        let lower = word.lowercased()
        return words.contains { $0.lowercased() == lower }
    }

    public static func add(_ word: String) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !contains(trimmed) else { return false }
        var current = words
        current.append(trimmed)
        UserDefaults.standard.set(current, forKey: key)
        return true
    }

    public static func remove(_ word: String) {
        var current = words
        current.removeAll { $0.lowercased() == word.lowercased() }
        UserDefaults.standard.set(current, forKey: key)
    }

    public static func resetToDefaults() {
        UserDefaults.standard.set(defaultExcludedWords, forKey: key)
    }
}
