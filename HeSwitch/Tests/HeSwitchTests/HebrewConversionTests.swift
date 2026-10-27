import XCTest
@testable import HeSwitch

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
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("אם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("גם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("עם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("רק"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("נשמע"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("hello"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("שלום"))
    }

    func testWordBoundaryExtraction() {
        XCTAssertEqual(WordBoundary.precedingWord(in: "akuo ", allowDelimiter: true), "akuo")
        XCTAssertEqual(WordBoundary.precedingWord(in: "t,v ", allowDelimiter: true), "t,v")
        XCTAssertEqual(WordBoundary.precedingWord(in: "mv\"k ", allowDelimiter: true), "mv\"k")
        XCTAssertEqual(WordBoundary.precedingWord(in: "׳hat ", allowDelimiter: true), "׳hat")
        XCTAssertEqual(WordBoundary.precedingWord(in: "ho׳ ", allowDelimiter: true), "ho׳")
        XCTAssertEqual(WordBoundary.precedingWord(in: "צג ", allowDelimiter: true), "צג")
        XCTAssertEqual(WordBoundary.precedingWord(in: "README.צג ", allowDelimiter: true), "צג")
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
