import XCTest
@testable import HastifyCore

final class AmountParserTests: XCTestCase {
    private func parse(_ text: String) -> Decimal? { AmountParser.parse(text) }

    func testPlainNumbers() {
        XCTAssertEqual(parse("12.34"), Decimal(string: "12.34"))
        XCTAssertEqual(parse("12"), 12)
    }

    func testCurrencySymbolsAndSpaces() {
        XCTAssertEqual(parse("$12.34"), Decimal(string: "12.34"))
        XCTAssertEqual(parse("12,34 €"), Decimal(string: "12.34"))
        XCTAssertEqual(parse(" £ 5.50 "), Decimal(string: "5.5"))
    }

    func testThousandsSeparators() {
        XCTAssertEqual(parse("1,234.56"), Decimal(string: "1234.56"))
        XCTAssertEqual(parse("1.234,56"), Decimal(string: "1234.56"))
        // Exactly three digits after the last separator is a thousands separator.
        XCTAssertEqual(parse("1,234"), 1234)
    }

    func testNoDigitsIsNil() {
        XCTAssertNil(parse(""))
        XCTAssertNil(parse("abc"))
        XCTAssertNil(parse("$"))
    }
}
