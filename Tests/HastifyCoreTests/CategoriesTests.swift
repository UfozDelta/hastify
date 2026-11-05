import XCTest
@testable import HastifyCore

final class CategoriesTests: XCTestCase {
    func testBuiltInKeywords() {
        XCTAssertEqual(Categorizer.category(for: "STARBUCKS #1234"), .coffee)
        XCTAssertEqual(Categorizer.category(for: "Whole Foods Market"), .groceries)
        XCTAssertEqual(Categorizer.category(for: "Chipotle"), .dining)
        XCTAssertEqual(Categorizer.category(for: "MTA*NYCT PAYGO"), .transit)
        XCTAssertEqual(Categorizer.category(for: "Target"), .shopping)
    }

    func testUnknownAndEmptyFallBackToOther() {
        XCTAssertEqual(Categorizer.category(for: "Joe's Hardware"), .other)
        XCTAssertEqual(Categorizer.category(for: ""), .other)
    }

    func testUserRulesBeatBuiltIns() {
        let rules = [CategoryRule(keyword: "target", category: .groceries)]
        XCTAssertEqual(Categorizer.category(for: "Target", rules: rules), .groceries)
        XCTAssertEqual(Categorizer.category(for: "Joe's Hardware", rules: [CategoryRule(keyword: "hardware", category: .shopping)]), .shopping)
    }

    func testBlankRuleMatchesNothing() {
        let rules = [CategoryRule(keyword: "  ", category: .dining)]
        XCTAssertEqual(Categorizer.category(for: "Joe's Hardware", rules: rules), .other)
    }

    func testTotalsGroupAndSortBiggestFirst() {
        func spend(_ amount: Decimal, _ merchant: String) -> Spend {
            Spend(date: Date(), amount: amount, merchant: merchant, card: "")
        }
        let totals = Categorizer.totals([
            spend(5, "Starbucks"), spend(4, "Dunkin"), spend(30, "Whole Foods"), spend(2, "Mystery"),
        ])
        XCTAssertEqual(totals.map(\.category), [.groceries, .coffee, .other])
        XCTAssertEqual(totals[1].total, 9)
        XCTAssertEqual(totals[1].count, 2)
    }
}
