import Foundation

public enum ExclusionLanguage: String, Codable, CaseIterable {
    case any = "any"
    case english = "english"
    case hebrew = "hebrew"

    public var title: String {
        switch self {
        case .any: return "Both / Any"
        case .english: return "English"
        case .hebrew: return "Hebrew"
        }
    }

    public var badge: String {
        switch self {
        case .any: return "ALL"
        case .english: return "EN"
        case .hebrew: return "HE"
        }
    }
}

public struct ExcludedWordItem: Codable, Identifiable, Hashable {
    public var id: String { "\(word.lowercased())_\(language.rawValue)" }
    public let word: String
    public let language: ExclusionLanguage

    public init(word: String, language: ExclusionLanguage = .any) {
        self.word = word
        self.language = language
    }
}

public enum ExcludedWords {
    private static let key = "excludedWordsItems"
    private static let legacyKey = "excludedWordsList"

    public static let defaultExcludedItems: [ExcludedWordItem] = [
        ExcludedWordItem(word: "ls", language: .english),
        ExcludedWordItem(word: "cd", language: .english),
        ExcludedWordItem(word: "rm", language: .english),
        ExcludedWordItem(word: "cp", language: .english),
        ExcludedWordItem(word: "mv", language: .english),
        ExcludedWordItem(word: "ps", language: .english),
        ExcludedWordItem(word: "df", language: .english),
        ExcludedWordItem(word: "du", language: .english),
        ExcludedWordItem(word: "vi", language: .english),
        ExcludedWordItem(word: "sh", language: .english),
        ExcludedWordItem(word: "id", language: .english)
    ]

    public static var items: [ExcludedWordItem] {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ExcludedWordItem].self, from: data) {
            return decoded
        }
        if let legacy = UserDefaults.standard.stringArray(forKey: legacyKey) {
            let migrated = legacy.map { ExcludedWordItem(word: $0, language: .any) }
            save(migrated)
            return migrated
        }
        return defaultExcludedItems
    }

    public static var words: [String] {
        items.map(\.word)
    }

    public static func contains(_ word: String) -> Bool {
        let lower = word.lowercased()
        return items.contains { $0.word.lowercased() == lower }
    }

    public static func isExcluded(_ word: String, language: KeyboardLanguage? = nil) -> Bool {
        let lower = word.lowercased()
        return items.contains { item in
            guard item.word.lowercased() == lower else { return false }
            if item.language == .any { return true }
            guard let lang = language else { return true }
            switch (item.language, lang) {
            case (.english, .english): return true
            case (.hebrew, .hebrew): return true
            default: return false
            }
        }
    }

    public static func add(_ word: String, language: ExclusionLanguage = .any) -> Bool {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var current = items
        if current.contains(where: { $0.word.lowercased() == trimmed.lowercased() && ($0.language == language || $0.language == .any) }) {
            return false
        }
        current.append(ExcludedWordItem(word: trimmed, language: language))
        save(current)
        return true
    }

    public static func remove(_ word: String, language: ExclusionLanguage? = nil) {
        var current = items
        current.removeAll { item in
            guard item.word.lowercased() == word.lowercased() else { return false }
            if let lang = language {
                return item.language == lang
            }
            return true
        }
        save(current)
    }

    public static func resetToDefaults() {
        save(defaultExcludedItems)
    }

    private static func save(_ list: [ExcludedWordItem]) {
        if let data = try? JSONEncoder().encode(list) {
            UserDefaults.standard.set(data, forKey: key)
            UserDefaults.standard.set(list.map(\.word), forKey: legacyKey)
        }
    }
}
