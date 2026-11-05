import XCTest
@testable import HastifyCore

final class SavingsStatsTests: XCTestCase {
    private let cal = Calendar.current
    private lazy var now = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func day(_ daysAgo: Int) -> Date { cal.date(byAdding: .day, value: -daysAgo, to: now)! }

    private func spend(_ amount: Decimal, daysAgo: Int) -> Spend {
        Spend(date: day(daysAgo), amount: amount, merchant: "Shop", card: "Card")
    }

    private func goal(target: Decimal, startedDaysAgo: Int) -> SavingsGoal {
        SavingsGoal(name: "Trip", target: target, startDate: day(startedDaysAgo))
    }

    func testSavedIsBudgetMinusSpendOnCompletedDays() {
        // Days 3, 2, 1 ago are complete: spent 0, 40, 60 against a 50 budget => saved 50 + 10 + 0.
        let spends = [spend(40, daysAgo: 2), spend(60, daysAgo: 1)]
        let progress = SavingsStats.progress(goal: goal(target: 500, startedDaysAgo: 3), budget: 50, spends: spends, now: now)
        XCTAssertEqual(progress.saved, 60)
        XCTAssertEqual(progress.remaining, 440)
        XCTAssertFalse(progress.isDone)
    }

    func testTodayIsNotCounted() {
        let progress = SavingsStats.progress(goal: goal(target: 100, startedDaysAgo: 0), budget: 50, spends: [spend(10, daysAgo: 0)], now: now)
        XCTAssertEqual(progress.saved, 0)
    }

    func testStreakCountsDaysAtOrUnderBudgetEndingYesterday() {
        // 3 ago: over, 2 ago: under, 1 ago: exactly on budget.
        let spends = [spend(80, daysAgo: 3), spend(10, daysAgo: 2), spend(50, daysAgo: 1)]
        let progress = SavingsStats.progress(goal: goal(target: 500, startedDaysAgo: 3), budget: 50, spends: spends, now: now)
        XCTAssertEqual(progress.streak, 2)
    }

    func testGoalReachedAndFraction() {
        let progress = SavingsStats.progress(goal: goal(target: 100, startedDaysAgo: 3), budget: 50, spends: [], now: now)
        XCTAssertEqual(progress.saved, 150)
        XCTAssertTrue(progress.isDone)
        XCTAssertEqual(progress.fraction, 1)
        XCTAssertEqual(progress.remaining, 0)
        XCTAssertNil(progress.eta)
    }

    func testEstimatedFinishFromPace() {
        // Saves 50 a day, target 200, 2 days done => 100 saved, 2 more days to go.
        let progress = SavingsStats.progress(goal: goal(target: 200, startedDaysAgo: 2), budget: 50, spends: [], now: now)
        XCTAssertEqual(progress.saved, 100)
        let expected = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))
        XCTAssertEqual(progress.eta, expected)
    }

    func testNoEstimateWhenNothingSaved() {
        let spends = [spend(60, daysAgo: 2), spend(60, daysAgo: 1)]
        let progress = SavingsStats.progress(goal: goal(target: 500, startedDaysAgo: 2), budget: 50, spends: spends, now: now)
        XCTAssertEqual(progress.saved, 0)
        XCTAssertNil(progress.eta)
    }
}
