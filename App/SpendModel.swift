import SwiftUI
import WidgetKit

@MainActor
final class SpendModel: ObservableObject {
    /// Newest first.
    @Published private(set) var spends: [Spend] = []
    @Published private(set) var settings = SettingsStore.load()

    func reload() {
        spends = SpendStore.all().sorted { $0.date > $1.date }
        applySettings(SettingsStore.load())
    }

    func updateSettings(_ change: (inout Settings) -> Void) {
        var new = settings
        change(&new)
        guard new != settings else { return }
        SettingsStore.save(new)
        applySettings(new)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func applySettings(_ new: Settings) {
        // Set before publishing so views re-rendering on the change read the new accent.
        Theme.accent = new.theme.color
        if new != settings { settings = new }
    }

    /// Switches the Home Screen icon; nil restores the primary one.
    func setIcon(_ theme: AppTheme) {
        guard UIApplication.shared.supportsAlternateIcons,
              UIApplication.shared.alternateIconName != theme.iconName else { return }
        UIApplication.shared.setAlternateIconName(theme.iconName)
    }

    /// Writes every spend to a temp CSV (oldest first) and returns its URL for sharing.
    func csvFile() -> URL? {
        func field(_ text: String) -> String {
            text.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" })
                ? "\"" + text.replacingOccurrences(of: "\"", with: "\"\"") + "\""
                : text
        }
        let iso = ISO8601DateFormatter()
        let rows = spends.reversed().map { spend in
            [iso.string(from: spend.date), "\(spend.amount)", field(spend.merchant), field(spend.card)].joined(separator: ",")
        }
        let csv = (["date,amount,merchant,card"] + rows).joined(separator: "\n") + "\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("hastify-spending.csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    func add(_ spend: Spend) {
        SpendStore.add(spend)
        didChange()
    }

    func delete(ids: Set<UUID>) {
        SpendStore.delete(ids: ids)
        didChange()
    }

    func clearAll() {
        SpendStore.save([])
        didChange()
    }

    /// Fakes a Wallet transaction through the same path the Shortcuts trigger uses,
    /// including a currency-formatted amount string.
    func simulateTap() {
        let merchants = ["Starbucks", "Target", "Chipotle", "7-Eleven", "Whole Foods"]
        let cents = Int.random(in: 150...4500)
        let amount = "$\(cents / 100).\(String(format: "%02d", cents % 100))"
        SpendStore.log(amountText: amount, merchant: merchants.randomElement(), card: "Test Card")
        didChange()
    }

    private func didChange() {
        WidgetCenter.shared.reloadAllTimelines()
        reload()
    }
}

enum Theme {
    static var accent = SettingsStore.load().theme.color
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
