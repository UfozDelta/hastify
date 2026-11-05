import XCTest
@testable import HastifyCore

final class SpendStatsTests: XCTestCase {
    private let cal = Calendar.current
    /// Noon today, so offsets in whole days never cross a day boundary by accident.
    private lazy var now = cal.date(bySettingHour: 12, minute: 0, second: 0, of: Date())!

    private func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: -offset, to: now)! }

    private func spend(_ amount: Decimal, daysAgo: Int = 0, merchant: String = "Shop") -> Spend {
        Spend(date: day(daysAgo), amount: amount, merchant: merchant, card: "Card")
    }

    func testTotalAndOnDay() {
        let spends = [spend(10), spend(5), spend(7, daysAgo: 1)]
        XCTAssertEqual(SpendStats.total(spends), 22)
        XCTAssertEqual(SpendStats.total(SpendStats.on(now, spends)), 15)
        XCTAssertEqual(SpendStats.total(SpendStats.on(SpendStats.yesterday(now), spends)), 7)
    }

    func testDailyIsZeroFilledOldestFirst() {
        let series = SpendStats.daily([spend(10), spend(4, daysAgo: 2)], days: 3, now: now)
        XCTAssertEqual(series.map(\.total), [4, 0, 10])
        XCTAssertLessThan(series[0].day, series[2].day)
    }

    func testAverageOfDays() {
        let series = SpendStats.daily([spend(9)], days: 3, now: now)
        XCTAssertEqual(SpendStats.average(of: series), 3)
        XCTAssertEqual(SpendStats.average(of: []), 0)
    }

    func testAveragePerDayCountsEmptyDays() {
        // First spend 3 days ago => 4 calendar days including today.
        let spends = [spend(8, daysAgo: 3), spend(4)]
        XCTAssertEqual(SpendStats.averagePerDay(spends, now: now), 3)
        XCTAssertEqual(SpendStats.averagePerDay([], now: now), 0)
    }

    func testMerchantsGroupCaseInsensitivelyAndSortByTotal() {
        let spends = [
            spend(5, merchant: "Starbucks"),
            spend(6, merchant: " starbucks "),
            spend(20, merchant: "Target"),
            spend(1, merchant: ""),
        ]
        let groups = SpendStats.merchants(spends)
        XCTAssertEqual(groups.map(\.name), ["Target", "Starbucks", "Unknown"])
        XCTAssertEqual(groups[1].total, 11)
        XCTAssertEqual(groups[1].count, 2)
    }

    func testLastDaysIncludesTodayAndExcludesOlder() {
        let spends = [spend(1), spend(2, daysAgo: 1), spend(3, daysAgo: 2)]
        XCTAssertEqual(SpendStats.lastDays(2, spends, now: now).count, 2)
        XCTAssertEqual(SpendStats.lastDays(1, spends, now: now).count, 1)
    }
}
