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
    }

    func testHebrewToEnglishConversions() {
        XCTAssertEqual(LayoutConversion.convert("יקךךם")?.output, "hello")
        XCTAssertEqual(LayoutConversion.convert("'םרךג")?.output, "world")
        XCTAssertEqual(LayoutConversion.convert("טקד")?.output, "yes")
        XCTAssertEqual(LayoutConversion.convert("בםגק")?.output, "code")
        XCTAssertEqual(LayoutConversion.convert("ין")?.output, "hi")
    }

    func testHebrewAcronymsAndAbbreviations() {
        XCTAssertEqual(LayoutConversion.convert("mv\"k")?.output, "צה\"ל")
        XCTAssertEqual(LayoutConversion.convert(",\"t")?.output, "ת\"א")
        XCTAssertEqual(LayoutConversion.convert("ju\"k")?.output, "חו\"ל")
        XCTAssertEqual(LayoutConversion.convert("trv\"c")?.output, "ארה\"ב")
        XCTAssertEqual(LayoutConversion.convert("nbf\"k")?.output, "מנכ\"ל")
        XCTAssertEqual(LayoutConversion.convert("gu\"s")?.output, "עו\"ד")
        XCTAssertEqual(LayoutConversion.convert("su\"j")?.output, "דו\"ח")
        XCTAssertEqual(LayoutConversion.convert("m'hpx")?.output, "צ'יפס")
        XCTAssertEqual(LayoutConversion.convert("mwhpx")?.output, "צ'יפס")
    }

    func testDecimalAndNumberProtection() {
        XCTAssertEqual(LayoutConversion.convert("3.14"), nil)
        XCTAssertEqual(LayoutConversion.convert("1,000"), nil)
    }

    func testAmbiguousWordDetection() {
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("to"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("do"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("go"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("אם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("גם"))
        XCTAssertTrue(AmbiguousCollisions.isAmbiguousCollision("עם"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("hello"))
        XCTAssertFalse(AmbiguousCollisions.isAmbiguousCollision("שלום"))
    }

    func testWordBoundaryExtraction() {
        XCTAssertEqual(WordBoundary.precedingWord(in: "akuo ", allowDelimiter: true), "akuo")
        XCTAssertEqual(WordBoundary.precedingWord(in: "t,v ", allowDelimiter: true), "t,v")
        XCTAssertEqual(WordBoundary.precedingWord(in: "mv\"k ", allowDelimiter: true), "mv\"k")
        XCTAssertEqual(WordBoundary.precedingWord(in: "user@example.com ", allowDelimiter: true), nil)
        XCTAssertEqual(WordBoundary.precedingWord(in: "https://example.com ", allowDelimiter: true), nil)
    }
}
