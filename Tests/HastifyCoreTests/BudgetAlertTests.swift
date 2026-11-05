import XCTest
@testable import HastifyCore

final class BudgetAlertTests: XCTestCase {
    private func check(_ before: Decimal, _ after: Decimal, budget: Decimal = 100) -> BudgetAlert? {
        BudgetAlert.check(before: before, after: after, budget: budget)
    }

    func testNearingFiresWhenCrossing80Percent() {
        XCTAssertEqual(check(70, 85), .nearing)
        XCTAssertEqual(check(79, 80), .nearing)
    }

    func testNearingDoesNotRepeatOnceAlreadyPast80() {
        XCTAssertNil(check(85, 90))
        XCTAssertNil(check(80, 95))
    }

    func testOverFiresWhenCrossingTheBudget() {
        XCTAssertEqual(check(90, 110), .over)
        XCTAssertEqual(check(100, 101), .over)
    }

    func testJumpingStraightOverReportsOnlyOver() {
        XCTAssertEqual(check(10, 150), .over)
    }

    func testNoRepeatOnceAlreadyOver() {
        XCTAssertNil(check(110, 120))
    }

    func testExactlyOnBudgetIsNotOver() {
        XCTAssertNil(check(90, 100))
    }

    func testNothingWithoutABudgetOrIncrease() {
        XCTAssertNil(check(10, 20, budget: 0))
        XCTAssertNil(check(50, 50))
        XCTAssertNil(check(90, 50))
    }
}
