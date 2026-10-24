import SwiftUI
import WidgetKit

@MainActor
final class SpendModel: ObservableObject {
    /// Newest first.
    @Published private(set) var spends: [Spend] = []

    func reload() {
        spends = SpendStore.all().sorted { $0.date > $1.date }
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
    static let accent = Color(red: 0.55, green: 0.36, blue: 0.96)
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
