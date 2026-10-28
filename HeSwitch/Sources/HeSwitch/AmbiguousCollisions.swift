import Foundation

/// Safeguards against ambiguous short words that are valid in both languages.
/// E.g. "to" in English vs "אם" in Hebrew, or "do" in English vs "גם" in Hebrew.
public enum AmbiguousCollisions {
    /// Common pairs that should NOT be automatically swapped without surrounding context
    public static let blockedIsolatedSwaps: Set<String> = [
        "to", "do", "go", "so", "no", "an", "ha", "as", "re", "bang", "nut", "bar", "car", "in",
        "אם", "גם", "עם", "דם", "נם", "שם", "יש", "שד", "רק", "נשמע", "הוא", "נשר", "בשר", "ןמ",
        "md", "צג", "tbh", "אני"
    ]

    /// Returns true if an automatic swap should be suppressed to avoid false positives.
    public static func isAmbiguousCollision(_ word: String) -> Bool {
        blockedIsolatedSwaps.contains(word.lowercased())
    }
}
