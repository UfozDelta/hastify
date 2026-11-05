import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

struct Spend: Codable, Identifiable, Hashable {
    var id = UUID()
    var date: Date
    var amount: Decimal
    var merchant: String
    var card: String
}

enum Currency {
    static var code: String { Locale.current.currency?.identifier ?? "USD" }
}

/// JSON file in the shared App Group container, read by both the app and the widget.
enum SpendStore {
    static let appGroup = "group.com.hastify.app"
    private static let fileName = "spends.json"

    /// AltStore/SideStore rename App Group IDs when re-signing and list the real ones
    /// under `ALTAppGroups` in Info.plist (of the app, and sometimes the extension).
    private static var containerURL: URL? {
        var bundles = [Bundle.main]
        if Bundle.main.bundleURL.pathExtension == "appex",
           let host = Bundle(url: Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent()) {
            bundles.append(host)
        }
        let altGroups = bundles.flatMap { $0.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] ?? [] }
        for id in altGroups + [appGroup] {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: id) {
                return url
            }
        }
        return nil
    }

    /// Tests point the store at a temp folder instead of the App Group container.
    static var directoryOverride: URL?

    static func fileURL(named name: String) -> URL {
        if let directoryOverride { return directoryOverride.appendingPathComponent(name) }
        let dir = containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(name)
    }

    /// Cross-process lock (the app, the widget and the intent all write spends.json), so two
    /// read-modify-write cycles can't overwrite each other and lose a tap. Not reentrant.
    private static func locked<T>(_ body: () -> T) -> T {
        let fd = open(fileURL(named: "spends.lock").path, O_CREAT | O_RDWR, 0o644)
        guard fd >= 0 else { return body() }
        flock(fd, LOCK_EX)
        defer {
            flock(fd, LOCK_UN)
            close(fd)
        }
        return body()
    }

    private static var fileURL: URL { fileURL(named: fileName) }

    static func all() -> [Spend] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Spend].self, from: data)) ?? []
    }

    static func save(_ spends: [Spend]) {
        guard let data = try? JSONEncoder().encode(spends) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func add(_ spend: Spend) {
        locked { save(all() + [spend]) }
    }

    enum LogResult: Equatable {
        case logged(Decimal)
        case invalidAmount
        case ignored
        /// Same amount, merchant and card as a tap seconds ago; the automation can fire twice.
        case duplicate
    }

    /// Entry point for both the Log Spend intent and the in-app simulator.
    @discardableResult
    static func log(amountText: String, merchant: String?, card: String?, now: Date = .now) -> LogResult {
        guard let value = AmountParser.parse(amountText), value > 0 else { return .invalidAmount }
        guard !SettingsStore.load().isIgnored(merchant ?? "") else { return .ignored }
        let spend = Spend(date: now, amount: value, merchant: merchant ?? "", card: card ?? "")
        return locked {
            let existing = all()
            if isDuplicate(spend, in: existing) { return .duplicate }
            save(existing + [spend])
            return .logged(value)
        }
    }

    /// True when `spend` matches an existing one within `window` seconds.
    static func isDuplicate(_ spend: Spend, in existing: [Spend], window: TimeInterval = 30) -> Bool {
        existing.contains {
            $0.amount == spend.amount
                && $0.merchant == spend.merchant
                && $0.card == spend.card
                && abs($0.date.timeIntervalSince(spend.date)) <= window
        }
    }

    static func delete(ids: Set<UUID>) {
        locked { save(all().filter { !ids.contains($0.id) }) }
    }

    static func today(_ now: Date = .now) -> [Spend] {
        all().filter { Calendar.current.isDate($0.date, inSameDayAs: now) }
    }

    static func total(_ spends: [Spend]) -> Decimal {
        spends.reduce(0) { $0 + $1.amount }
    }
}

enum AmountParser {
    /// Accepts whatever Shortcuts hands over: "$12.34", "12,34 €", "1,234.56", "12.34".
    static func parse(_ raw: String) -> Decimal? {
        let digits = raw.filter { ("0"..."9").contains($0) || $0 == "." || $0 == "," }
        guard !digits.isEmpty else { return nil }
        guard let sep = digits.lastIndex(where: { $0 == "." || $0 == "," }) else {
            return Decimal(string: digits)
        }
        let whole = String(digits[..<sep].filter { ("0"..."9").contains($0) })
        let fraction = String(digits[digits.index(after: sep)...])
        // Exactly 3 digits after the last separator means a thousands separator ("1,234").
        let normalized = fraction.count == 3 ? whole + fraction : whole + "." + fraction
        return Decimal(string: normalized)
    }
}
