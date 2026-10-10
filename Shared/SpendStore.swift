import Foundation

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

    private static var fileURL: URL {
        let dir = containerURL ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent(fileName)
    }

    static func all() -> [Spend] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Spend].self, from: data)) ?? []
    }

    static func save(_ spends: [Spend]) {
        guard let data = try? JSONEncoder().encode(spends) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func add(_ spend: Spend) {
        save(all() + [spend])
    }

    static func delete(ids: Set<UUID>) {
        save(all().filter { !ids.contains($0.id) })
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
