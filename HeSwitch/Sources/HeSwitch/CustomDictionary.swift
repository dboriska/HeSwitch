import Foundation

public enum CustomDictionary {
    private static let key = "customDictionaryWords"

    public static var words: [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
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
}
