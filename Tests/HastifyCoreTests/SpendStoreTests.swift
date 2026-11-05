import XCTest
@testable import HastifyCore

final class SpendStoreTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("hastify-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        SpendStore.directoryOverride = dir
    }

    override func tearDownWithError() throws {
        SpendStore.directoryOverride = nil
        try? FileManager.default.removeItem(at: dir)
    }

    func testLogSavesAndParsesCurrencyText() {
        XCTAssertEqual(SpendStore.log(amountText: "$4.50", merchant: "Cafe", card: "Visa"), .logged(Decimal(string: "4.5")!))
        let all = SpendStore.all()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all[0].merchant, "Cafe")
        XCTAssertEqual(all[0].card, "Visa")
    }

    func testLogRejectsBadOrZeroAmounts() {
        XCTAssertEqual(SpendStore.log(amountText: "free", merchant: "Cafe", card: nil), .invalidAmount)
        XCTAssertEqual(SpendStore.log(amountText: "0", merchant: "Cafe", card: nil), .invalidAmount)
        XCTAssertTrue(SpendStore.all().isEmpty)
    }

    func testIgnoredMerchantIsSkipped() {
        SettingsStore.save(Settings(ignoredMerchants: ["MTA"]))
        XCTAssertEqual(SpendStore.log(amountText: "2.90", merchant: "MTA*NYCT PAYGO", card: nil), .ignored)
        XCTAssertTrue(SpendStore.all().isEmpty)
    }

    func testDuplicateTapWithinWindowIsSkipped() {
        let t = Date()
        XCTAssertEqual(SpendStore.log(amountText: "9.99", merchant: "Cafe", card: "Visa", now: t), .logged(Decimal(string: "9.99")!))
        XCTAssertEqual(SpendStore.log(amountText: "9.99", merchant: "Cafe", card: "Visa", now: t.addingTimeInterval(5)), .duplicate)
        XCTAssertEqual(SpendStore.all().count, 1)
    }

    func testSameTapOutsideWindowOrDifferentDetailsIsKept() {
        let t = Date()
        SpendStore.log(amountText: "9.99", merchant: "Cafe", card: "Visa", now: t)
        SpendStore.log(amountText: "9.99", merchant: "Cafe", card: "Visa", now: t.addingTimeInterval(120))
        SpendStore.log(amountText: "9.99", merchant: "Other", card: "Visa", now: t.addingTimeInterval(121))
        XCTAssertEqual(SpendStore.all().count, 3)
    }

    func testIsDuplicateWindowBoundary() {
        let t = Date()
        let base = Spend(date: t, amount: 5, merchant: "A", card: "C")
        let inside = Spend(date: t.addingTimeInterval(30), amount: 5, merchant: "A", card: "C")
        let outside = Spend(date: t.addingTimeInterval(31), amount: 5, merchant: "A", card: "C")
        XCTAssertTrue(SpendStore.isDuplicate(inside, in: [base]))
        XCTAssertFalse(SpendStore.isDuplicate(outside, in: [base]))
    }

    func testDeleteRemovesOnlyGivenIds() {
        let a = Spend(date: Date(), amount: 1, merchant: "A", card: "")
        let b = Spend(date: Date(), amount: 2, merchant: "B", card: "")
        SpendStore.add(a)
        SpendStore.add(b)
        SpendStore.delete(ids: [a.id])
        XCTAssertEqual(SpendStore.all().map(\.merchant), ["B"])
    }

    func testConcurrentAddsDoNotLoseWrites() {
        let count = 40
        DispatchQueue.concurrentPerform(iterations: count) { i in
            SpendStore.add(Spend(date: Date(), amount: Decimal(i + 1), merchant: "M\(i)", card: ""))
        }
        XCTAssertEqual(SpendStore.all().count, count)
    }
}

final class SettingsTests: XCTestCase {
    func testIgnoredMatchIsCaseInsensitiveSubstring() {
        let settings = Settings(ignoredMerchants: ["mta", "  ", "Clipper"])
        XCTAssertTrue(settings.isIgnored("MTA*NYCT PAYGO"))
        XCTAssertTrue(settings.isIgnored("clipper card"))
        XCTAssertFalse(settings.isIgnored("Starbucks"))
        // Blank rules must not match everything.
        XCTAssertFalse(Settings(ignoredMerchants: [" "]).isIgnored("Starbucks"))
    }
}
