import XCTest
@testable import HeSwitch

@MainActor
final class HebrewConversionTests: XCTestCase {
    func testEnglishToHebrewConversions() {
        XCTAssertEqual(LayoutConversion.convert("akuo")?.output, "שלום")
        XCTAssertEqual(LayoutConversion.convert("Akuo")?.output, "שלום")
        XCTAssertEqual(LayoutConversion.convert("AKUO")?.output, "שלום")
        XCTAssertEqual(LayoutConversion.convert("nv bang")?.output, "מה נשמע")
        XCTAssertEqual(LayoutConversion.convert("cuer yuc")?.output, "בוקר טוב")
        XCTAssertEqual(LayoutConversion.convert("t,v")?.output, "אתה")
        XCTAssertEqual(LayoutConversion.convert("t,")?.output, "את")
        XCTAssertEqual(LayoutConversion.convert("tbjbu")?.output, "אנחנו")
        XCTAssertEqual(LayoutConversion.convert("thpv")?.output, "איפה")
        XCTAssertEqual(LayoutConversion.convert("knv")?.output, "למה")
        XCTAssertEqual(LayoutConversion.convert("fnv")?.output, "כמה")
        XCTAssertEqual(LayoutConversion.convert("n,h")?.output, "מתי")
        XCTAssertEqual(LayoutConversion.convert("rumv")?.output, "רוצה")
        XCTAssertEqual(LayoutConversion.convert("husg")?.output, "יודע")
        XCTAssertEqual(LayoutConversion.convert("gcrh,")?.output, "עברית")
        XCTAssertEqual(LayoutConversion.convert("tbdkh,")?.output, "אנגלית")
        XCTAssertEqual(LayoutConversion.convert("what")?.output, "׳ישא")
        XCTAssertEqual(LayoutConversion.convert("how")?.output, "ים׳")
    }

    func testHebrewToEnglishConversions() {
        XCTAssertEqual(LayoutConversion.convert("יקךךם")?.output, "hello")
        XCTAssertEqual(LayoutConversion.convert("׳םרךג")?.output, "world")
        XCTAssertEqual(LayoutConversion.convert("'םרךג")?.output, "world")
        XCTAssertEqual(LayoutConversion.convert("טקד")?.output, "yes")
        XCTAssertEqual(LayoutConversion.convert("בםגק")?.output, "code")
        XCTAssertEqual(LayoutConversion.convert("ין")?.output, "hi")
        XCTAssertEqual(LayoutConversion.convert("שמג")?.output, "and")
        XCTAssertEqual(LayoutConversion.convert("שגג")?.output, "add")
        XCTAssertEqual(LayoutConversion.convert("צג")?.output, "md")
        XCTAssertEqual(LayoutConversion.convert("׳ישא")?.output, "what")
        XCTAssertEqual(LayoutConversion.convert("'ישא")?.output, "what")
        XCTAssertEqual(LayoutConversion.convert("ים׳")?.output, "how")
        XCTAssertEqual(LayoutConversion.convert("ים'")?.output, "how")
        XCTAssertEqual(LayoutConversion.convert("׳יקמ")?.output, "when")
        XCTAssertEqual(LayoutConversion.convert("׳יקרק")?.output, "where")
        XCTAssertEqual(LayoutConversion.convert("׳יט")?.output, "why")
        XCTAssertEqual(LayoutConversion.convert("׳ים")?.output, "who")
        XCTAssertEqual(LayoutConversion.convert("׳ןאי")?.output, "with")
        XCTAssertEqual(LayoutConversion.convert("׳ןךך")?.output, "will")
    }

    func testMixedHebrewGereshLetterWConversions() {
        // Words typed when user starts in Hebrew or produces Geresh for W:
        XCTAssertEqual(LayoutConversion.convert("׳hat")?.output, "what")
        XCTAssertEqual(LayoutConversion.convert("ho׳")?.output, "how")
        XCTAssertEqual(LayoutConversion.convert("׳orld")?.output, "world")
        XCTAssertEqual(LayoutConversion.convert("׳hen")?.output, "when")
        XCTAssertEqual(LayoutConversion.convert("to׳er")?.output, "tower")
    }

    func testCapitalizedEnglishTypedInHebrewLayout() {
        // Double-quote / Gershayim prefix for Shift + W typed in macOS Hebrew layout:
        XCTAssertEqual(LayoutConversion.convert("״ישא")?.output, "What")
        XCTAssertEqual(LayoutConversion.convert("\"ישא")?.output, "What")
        XCTAssertEqual(LayoutConversion.convert("״hat")?.output, "What")
        XCTAssertEqual(LayoutConversion.convert("\"hat")?.output, "What")
        XCTAssertEqual(LayoutConversion.convert("״יקמ")?.output, "When")
        XCTAssertEqual(LayoutConversion.convert("\"יקמ")?.output, "When")
        XCTAssertEqual(LayoutConversion.convert("״hen")?.output, "When")
        XCTAssertEqual(LayoutConversion.convert("\"hen")?.output, "When")
        XCTAssertEqual(LayoutConversion.convert("״יקרק")?.output, "Where")
        XCTAssertEqual(LayoutConversion.convert("\"יקרק")?.output, "Where")
        XCTAssertEqual(LayoutConversion.convert("״here")?.output, "Where")
        XCTAssertEqual(LayoutConversion.convert("\"here")?.output, "Where")
        XCTAssertEqual(LayoutConversion.convert("״יט")?.output, "Why")
        XCTAssertEqual(LayoutConversion.convert("\"יט")?.output, "Why")
        XCTAssertEqual(LayoutConversion.convert("״hy")?.output, "Why")
        XCTAssertEqual(LayoutConversion.convert("\"hy")?.output, "Why")
        XCTAssertEqual(LayoutConversion.convert("״ים")?.output, "Who")
        XCTAssertEqual(LayoutConversion.convert("\"ים")?.output, "Who")
        XCTAssertEqual(LayoutConversion.convert("״ho")?.output, "Who")
        XCTAssertEqual(LayoutConversion.convert("\"ho")?.output, "Who")
        XCTAssertEqual(LayoutConversion.convert("״םרךג")?.output, "World")
        XCTAssertEqual(LayoutConversion.convert("\"םרךג")?.output, "World")
        XCTAssertEqual(LayoutConversion.convert("״ןךך")?.output, "Will")
        XCTAssertEqual(LayoutConversion.convert("\"ןךך")?.output, "Will")
        XCTAssertEqual(LayoutConversion.convert("״ןאי")?.output, "With")
        XCTAssertEqual(LayoutConversion.convert("\"ןאי")?.output, "With")
        XCTAssertEqual(LayoutConversion.convert("״קקל")?.output, "Week")
        XCTAssertEqual(LayoutConversion.convert("\"קקל")?.output, "Week")
        XCTAssertEqual(LayoutConversion.convert("״eek")?.output, "Week")
        XCTAssertEqual(LayoutConversion.convert("״שאקר")?.output, "Water")
        XCTAssertEqual(LayoutConversion.convert("\"שאקר")?.output, "Water")
        XCTAssertEqual(LayoutConversion.convert("״ןמגם׳ד")?.output, "Windows")
        XCTAssertEqual(LayoutConversion.convert("\"ןמגם׳ד")?.output, "Windows")
        XCTAssertEqual(LayoutConversion.convert("״indows")?.output, "Windows")
        XCTAssertEqual(LayoutConversion.convert("״קנ")?.output, "Web")
        XCTAssertEqual(LayoutConversion.convert("\"קנ")?.output, "Web")
        XCTAssertEqual(LayoutConversion.convert("״eb")?.output, "Web")

        // Words typed starting with Shift (uppercase Latin) followed by Hebrew letters:
        XCTAssertEqual(LayoutConversion.convert("Wישא")?.output, "What")
        XCTAssertEqual(LayoutConversion.convert("Wיקמ")?.output, "When")
        XCTAssertEqual(LayoutConversion.convert("Wיקרק")?.output, "Where")
        XCTAssertEqual(LayoutConversion.convert("Wיט")?.output, "Why")
        XCTAssertEqual(LayoutConversion.convert("Wים")?.output, "Who")
        XCTAssertEqual(LayoutConversion.convert("Wםרךג")?.output, "World")
        XCTAssertEqual(LayoutConversion.convert("Wןךך")?.output, "Will")
        XCTAssertEqual(LayoutConversion.convert("Wןאי")?.output, "With")
        XCTAssertEqual(LayoutConversion.convert("Wקקל")?.output, "Week")
        XCTAssertEqual(LayoutConversion.convert("Wשאקר")?.output, "Water")
        XCTAssertEqual(LayoutConversion.convert("Wןמגם׳ד")?.output, "Windows")
        XCTAssertEqual(LayoutConversion.convert("Wקנ")?.output, "Web")
        XCTAssertEqual(LayoutConversion.convert("Hקךךם")?.output, "Hello")
        XCTAssertEqual(LayoutConversion.convert("Pךקשדק")?.output, "Please")
        XCTAssertEqual(LayoutConversion.convert("Hם׳")?.output, "How")
        XCTAssertEqual(LayoutConversion.convert("Tישמלד")?.output, "Thanks")
        XCTAssertEqual(LayoutConversion.convert("Tיק")?.output, "The")
        XCTAssertEqual(LayoutConversion.convert("Tיקרק")?.output, "There")
        XCTAssertEqual(LayoutConversion.convert("Tיןד")?.output, "This")
        XCTAssertEqual(LayoutConversion.convert("Tיקט")?.output, "They")
        XCTAssertEqual(LayoutConversion.convert("Iדרשקך")?.output, "Israel")
        XCTAssertEqual(LayoutConversion.convert("Gםםעךק")?.output, "Google")
        XCTAssertEqual(LayoutConversion.convert("Yםו")?.output, "You")
        XCTAssertEqual(LayoutConversion.convert("Aמג")?.output, "And")
        XCTAssertEqual(LayoutConversion.convert("Hן")?.output, "Hi")
        XCTAssertEqual(LayoutConversion.convert("Iד")?.output, "Is")
        XCTAssertEqual(LayoutConversion.convert("Yקד")?.output, "Yes")
        XCTAssertEqual(LayoutConversion.convert("Oל")?.output, "Ok")
        XCTAssertEqual(LayoutConversion.convert("Cםגק")?.output, "Code")
        XCTAssertEqual(LayoutConversion.convert("Tקדא")?.output, "Test")
    }

    func testSelectionAndTranscriptConversions() {
        // Multi-word / sentence selection conversions (Option 1: Cmd + Shift + X)
        XCTAssertEqual(LayoutConversion.convertTextOrSelection("akuo nv bang")?.output, "שלום מה נשמע")
        XCTAssertEqual(LayoutConversion.convertTextOrSelection("שלום מה נשמע")?.output, "akuo nv bang")
        XCTAssertEqual(LayoutConversion.convertTextOrSelection("יקךךםת ים׳ שרק טםו?")?.output, "hello, how are you?")
        XCTAssertEqual(LayoutConversion.convertTextOrSelection("Line 1: akuo\nLine 2: ckg")?.output, "ךןמק 1: שלום\nךןמק 2: בלע")
    }

    func testHighFrequencyVocabulary() {
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("and", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("add", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("md", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("what", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("how", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("world", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("when", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("where", language: .english))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("שלום", language: .hebrew))
        XCTAssertTrue(HighFrequencyVocabulary.isHighFrequency("בוקר", language: .hebrew))
    }

    func testHebrewAcronymsAndAbbreviations() {
        XCTAssertEqual(LayoutConversion.convert("mv\"k")?.output, "צה\"ל")
        XCTAssertEqual(LayoutConversion.convert(",\"t")?.output, "ת\"א")
        XCTAssertEqual(LayoutConversion.convert("ju\"k")?.output, "חו\"ל")
        XCTAssertEqual(LayoutConversion.convert("trv\"c")?.output, "ארה\"ב")
        XCTAssertEqual(LayoutConversion.convert("nbf\"k")?.output, "מנכ\"ל")
        XCTAssertEqual(LayoutConversion.convert("gu\"s")?.output, "עו\"ד")
        XCTAssertEqual(LayoutConversion.convert("su\"j")?.output, "דו\"ח")
        XCTAssertEqual(LayoutConversion.convert("mwhpx")?.output, "צ׳יפס")
    }

    func testDecimalAndNumberProtection() {
        XCTAssertEqual(LayoutConversion.convert("3.14"), nil)
        XCTAssertEqual(LayoutConversion.convert("1,000"), nil)
    }

    func testAmbiguousWordDetection() {
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("to"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("do"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("go"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("re"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("bang"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("md"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("צג"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("tbh"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("אני"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("אם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("גם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("עם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("רק"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("נשמע"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("hello"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("שלום"))
    }

    func testScriptCoherenceContext() {
        XCTAssertEqual(DecisionEngine.scriptOfContext("שלום לכולם "), .hebrew)
        XCTAssertEqual(DecisionEngine.scriptOfContext("hello world "), .english)
        XCTAssertEqual(DecisionEngine.scriptOfContext(""), .neutral)
        XCTAssertEqual(DecisionEngine.scriptOfContext("   "), .neutral)
        XCTAssertEqual(DecisionEngine.scriptOfContext("12345 "), .neutral)
        XCTAssertTrue(DecisionEngine.isCliCommandContext("cat README."))
        XCTAssertTrue(DecisionEngine.isCliCommandContext("vim notes."))
        XCTAssertFalse(DecisionEngine.isCliCommandContext("שלום קובץ."))
    }

    func testContextualAmbiguousConversions() {
        // 1. Hebrew line context continues in Hebrew:
        // When typing English layout by mistake in Hebrew context, convert to Hebrew:
        XCTAssertEqual(DecisionEngine.candidate(for: "tbh", context: "שלום, ")?.output, "אני")
        XCTAssertEqual(DecisionEngine.candidate(for: "md", context: "קניתי ")?.output, "צג")
        XCTAssertEqual(DecisionEngine.candidate(for: "kph", context: "שלום, ")?.output, "לפי")
        XCTAssertEqual(DecisionEngine.candidate(for: "to", context: "אני רוצה ")?.output, "אם")
        XCTAssertEqual(DecisionEngine.candidate(for: "do", context: "אני ")?.output, "גם")
        XCTAssertEqual(DecisionEngine.candidate(for: "go", context: "אני בא ")?.output, "עם")
        XCTAssertEqual(DecisionEngine.candidate(for: "re", context: "זה ")?.output, "רק")

        // When typing Hebrew in Hebrew context, keep Hebrew (DO NOT convert to English):
        XCTAssertNil(DecisionEngine.candidate(for: "אני", context: "שלום, "))
        XCTAssertNil(DecisionEngine.candidate(for: "צג", context: "קניתי "))
        XCTAssertNil(DecisionEngine.candidate(for: "לפי", context: "שלום, "))
        XCTAssertNil(DecisionEngine.candidate(for: "אם", context: "אני רוצה "))
        XCTAssertNil(DecisionEngine.candidate(for: "גם", context: "אני "))
        XCTAssertNil(DecisionEngine.candidate(for: "עם", context: "אני בא "))
        XCTAssertNil(DecisionEngine.candidate(for: "רק", context: "זה "))

        // 2. English line context continues in English:
        // When typing English in English context, keep English (DO NOT convert to Hebrew):
        XCTAssertNil(DecisionEngine.candidate(for: "tbh", context: "I think "))
        XCTAssertNil(DecisionEngine.candidate(for: "to", context: "I want "))
        XCTAssertNil(DecisionEngine.candidate(for: "do", context: "what should I "))
        XCTAssertNil(DecisionEngine.candidate(for: "go", context: "let us "))
        XCTAssertNil(DecisionEngine.candidate(for: "kph", context: "speed is 100 "))
        XCTAssertNil(DecisionEngine.candidate(for: "kph", context: "100 "))

        // When typing Hebrew by mistake in English context, convert to English:
        XCTAssertEqual(DecisionEngine.candidate(for: "אני", context: "I think ")?.output, "tbh")
        XCTAssertEqual(DecisionEngine.candidate(for: "צג", context: "Check the ")?.output, "md")
        XCTAssertEqual(DecisionEngine.candidate(for: "לפי", context: "speed was 100 ")?.output, "kph")
        XCTAssertEqual(DecisionEngine.candidate(for: "אם", context: "I want ")?.output, "to")
        XCTAssertEqual(DecisionEngine.candidate(for: "גם", context: "what should I ")?.output, "do")
        XCTAssertEqual(DecisionEngine.candidate(for: "עם", context: "let us ")?.output, "go")

        // 3. Special Markdown .צג / CLI conversions:
        XCTAssertEqual(DecisionEngine.candidate(for: "צג", context: "cat ")?.output, "md")
        XCTAssertEqual(DecisionEngine.candidate(for: "צג", context: "vim ")?.output, "md")
        XCTAssertEqual(DecisionEngine.candidate(for: "צג", context: "README.")?.output, "md")
        XCTAssertEqual(DecisionEngine.candidate(for: "צג", context: "", isTerminalApp: true)?.output, "md")

        // 4. Standalone / Neutral context (First word of line):
        // Protect legitimate words in isolation:
        XCTAssertNil(DecisionEngine.candidate(for: "אני", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "tbh", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "אם", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "to", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "גם", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "do", context: ""))
        XCTAssertNil(DecisionEngine.candidate(for: "לפי", context: ""))
        // 'kph' at start of line converts to 'לפי' because English sentences never start with 'kph',
        // whereas 'לפי' is a dominant Hebrew sentence starter:
        XCTAssertEqual(DecisionEngine.candidate(for: "kph", context: "")?.output, "לפי")
        XCTAssertEqual(DecisionEngine.candidate(for: "kph", context: nil)?.output, "לפי")
    }

    func testExcludedWords() {
        XCTAssertTrue(ExcludedWords.contains("ls"))
        XCTAssertTrue(ExcludedWords.contains("cd"))
        XCTAssertTrue(ExcludedWords.contains("rm"))
        XCTAssertFalse(ExcludedWords.contains("hello"))

        // Default CLI commands are excluded for English layout
        XCTAssertTrue(ExcludedWords.isExcluded("ls", language: .english))
        XCTAssertFalse(ExcludedWords.isExcluded("ls", language: .hebrew))

        // Add Hebrew-specific exclusion
        XCTAssertTrue(ExcludedWords.add("דג", language: .hebrew))
        XCTAssertTrue(ExcludedWords.isExcluded("דג", language: .hebrew))
        XCTAssertFalse(ExcludedWords.isExcluded("דג", language: .english))

        // Add generic exclusion
        XCTAssertTrue(ExcludedWords.add("testword", language: .any))
        XCTAssertTrue(ExcludedWords.isExcluded("testword", language: .english))
        XCTAssertTrue(ExcludedWords.isExcluded("testword", language: .hebrew))
        XCTAssertTrue(ExcludedWords.contains("testword"))

        ExcludedWords.remove("testword")
        XCTAssertFalse(ExcludedWords.contains("testword"))
        ExcludedWords.remove("דג")
    }

    func testWordBoundaryExtraction() {
        XCTAssertEqual(WordBoundary.precedingWord(in: "akuo ", allowDelimiter: true), "akuo")
        XCTAssertEqual(WordBoundary.precedingWord(in: "t,v ", allowDelimiter: true), "t,v")
        XCTAssertEqual(WordBoundary.precedingWord(in: "mv\"k ", allowDelimiter: true), "mv\"k")
        XCTAssertEqual(WordBoundary.precedingWord(in: "׳hat ", allowDelimiter: true), "׳hat")
        XCTAssertEqual(WordBoundary.precedingWord(in: "ho׳ ", allowDelimiter: true), "ho׳")
        XCTAssertEqual(WordBoundary.precedingWord(in: "צג ", allowDelimiter: true), "צג")
        XCTAssertEqual(WordBoundary.precedingWord(in: "README.צג ", allowDelimiter: true), "צג")
        XCTAssertEqual(WordBoundary.extractFileExtension(from: "README.צג"), "צג")
        XCTAssertEqual(WordBoundary.extractFileExtension(from: "notes.txt"), nil)
        XCTAssertEqual(WordBoundary.precedingWord(in: "user@example.com ", allowDelimiter: true), nil)
        XCTAssertEqual(WordBoundary.precedingWord(in: "https://example.com ", allowDelimiter: true), nil)
    }

    func testRandomizedTypingSequenceStress() {
        let pairs: [(en: String, he: String)] = [
            ("what", "׳ישא"),
            ("how", "ים׳"),
            ("when", "׳יקמ"),
            ("where", "׳יקרק"),
            ("why", "׳יט"),
            ("who", "׳ים"),
            ("with", "׳ןאי"),
            ("will", "׳ןךך"),
            ("world", "׳םרךג"),
            ("and", "שמג"),
            ("hello", "יקךךם"),
            ("code", "בםגק")
        ]
        for pair in pairs {
            let convToEn = LayoutConversion.convert(pair.he)
            XCTAssertEqual(convToEn?.output, pair.en)
            XCTAssertEqual(convToEn?.source, .hebrew)
            XCTAssertEqual(convToEn?.target, .english)

            let convToHe = LayoutConversion.convert(pair.en)
            XCTAssertEqual(convToHe?.output, pair.he)
            XCTAssertEqual(convToHe?.source, .english)
            XCTAssertEqual(convToHe?.target, .hebrew)
        }
    }
}
