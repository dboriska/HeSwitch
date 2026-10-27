import Foundation

/// Bundled top-frequency vocabulary sets for English and Hebrew.
/// These words bypass spelling ambiguities and prefix morphology false-positives
/// (such as Hebrew morphology treating "שמג" as valid prefixes + letter,
/// archaic Hebrew roots like "שגג" blocking "add", or "צג" blocking "md").
public enum HighFrequencyVocabulary {
    public static let englishWords: Set<String> = [
        "the", "be", "to", "of", "and", "a", "in", "that", "have", "i",
        "it", "for", "not", "on", "with", "he", "as", "you", "do", "at",
        "this", "but", "his", "by", "from", "they", "we", "say", "her", "she",
        "or", "an", "will", "my", "one", "all", "would", "there", "their", "what",
        "so", "up", "out", "if", "about", "who", "get", "which", "go", "me",
        "when", "make", "can", "like", "time", "no", "just", "him", "know", "take",
        "people", "into", "year", "your", "good", "some", "could", "them", "see", "other",
        "than", "then", "now", "look", "only", "come", "its", "over", "think", "also",
        "back", "after", "use", "two", "how", "our", "work", "first", "well", "way",
        "even", "new", "want", "because", "any", "these", "give", "day", "most", "us",
        "where", "why", "was", "were", "went", "while", "without", "within", "water",
        "word", "words", "week", "win", "wait", "watch", "walk", "wide", "wind", "winter",
        "wish", "woman", "women", "wrong", "web", "warn", "wear", "weather", "welcome",
        "west", "western", "whose", "whole", "worth", "few", "show", "slow", "flow",
        "grow", "draw", "view", "window", "windows", "between", "power", "tower", "allow", "follow",
        "below", "own", "down", "town", "worker", "working", "works", "write", "writer",
        "writing", "written", "wrote", "workflow", "workspace", "wrapper", "wonder", "wonderful",
        "warm", "warning", "website", "webpage", "widget", "wallet", "waste", "weight",
        "whatever", "whenever", "wherever", "whether", "willing", "winner", "winning",
        "wireless", "wisdom", "withdraw", "witness", "worry", "worried", "worse", "worst",
        "worthwhile", "wound", "wrap", "wreck", "wrist",
        // Common conversational & capitalized words:
        "hi", "hey", "hello", "yes", "ok", "bye", "is", "am", "are", "been", "has", "had",
        "did", "does", "got", "morning", "night", "thanks", "please", "google", "israel",
        "apple", "microsoft", "monday", "tuesday", "wednesday", "thursday", "friday",
        "saturday", "sunday", "january", "february", "march", "april", "may", "june",
        "july", "august", "september", "october", "november", "december", "english", "hebrew",
        // Common verbs & developer keywords:
        "add", "app", "ask", "key", "pay", "set", "put", "run",
        "log", "fix", "bug", "dev", "prod", "api", "url", "id", "cmd", "dir",
        "save", "load", "init", "info", "edit", "list", "item", "menu", "icon",
        "port", "host", "link", "path", "send", "auth", "type", "call", "sync",
        "done", "task", "date", "card", "page", "clean", "build", "start", "stop",
        "error", "debug", "release", "version", "install", "update", "upgrade",
        "delete", "remove", "create", "select", "insert", "search", "replace",
        "change", "switch", "toggle", "enable", "disable", "input", "output",
        "import", "export", "upload", "download",
        // Common file extensions & formats:
        "md", "ts", "js", "py", "sh", "rs", "sql", "css", "xml", "yml", "yaml",
        "json", "env", "bin", "src", "pkg", "txt", "doc", "pdf", "png", "jpg", "svg",
        // Code / Technical standard vocabulary:
        "code", "test", "world", "true", "false", "null", "func", "file", "open",
        "close", "read", "print", "data", "text", "name", "user", "pass", "help",
        "git", "branch", "commit", "push", "pull", "status", "checkout", "merge", "diff",
        "sudo", "brew", "curl", "bash", "zsh", "node", "npm", "echo", "find", "home"
    ]

    public static let hebrewWords: Set<String> = [
        "שלום", "בוקר", "טוב", "תודה", "בבקשה", "מה", "נשמע", "איך", "אתה", "את",
        "אנחנו", "איפה", "למה", "כמה", "מתי", "רוצה", "יודע", "עכשיו", "עבודה", "הודעה",
        "מחשב", "ישראל", "עברית", "אנגלית", "בסדר", "סבבה", "מצוין", "כן", "לא", "גם",
        "הוא", "היא", "הם", "הן", "זה", "זאת", "אלה", "כל", "רק", "עוד",
        "יום", "לילה", "שבוע", "חודש", "שנה", "בית", "ספר", "דרך", "מקום", "זמן",
        "צריך", "יכול", "היה", "היו", "יהיה", "רואה", "שומע", "הולך", "בא", "יוצא",
        "צה\"ל", "ת\"א", "חו\"ל", "ארה\"ב", "מנכ\"ל", "עו\"ד", "דו\"ח", "בד\"כ", "צ'יפס",
        "צה״ל", "ת״א", "חו״ל", "ארה״ב", "מנכ״ל", "עו״ד", "דו״ח", "בד״כ", "צ׳יפס",
        "ח\"כ", "ח״כ", "ש\"ח", "ש״ח", "תנ\"ך", "תנ״ך", "רוה\"מ", "רוה״מ"
    ]

    public static func isHighFrequency(_ word: String, language: KeyboardLanguage) -> Bool {
        let lower = word.lowercased()
        switch language {
        case .english:
            return englishWords.contains(lower)
        case .hebrew:
            return hebrewWords.contains(lower)
        }
    }
}
