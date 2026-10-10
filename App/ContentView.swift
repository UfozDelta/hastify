import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var spends: [Spend] = []
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            List {
                Section("Today") {
                    Text(SpendStore.total(spends).formatted(.currency(code: Currency.code)))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                }
                Section("Taps") {
                    if spends.isEmpty {
                        Text("No taps yet").foregroundStyle(.secondary)
                    }
                    ForEach(spends.reversed()) { spend in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(spend.merchant.isEmpty ? "Unknown" : spend.merchant)
                                Text(spend.date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(spend.amount.formatted(.currency(code: Currency.code)))
                                .monospacedDigit()
                        }
                    }
                    .onDelete(perform: delete)
                }
                Section("Setup") {
                    Text("""
                    Shortcuts → Automation → + → Transaction → pick all cards → Run Immediately.
                    Add action "Log Spend" (Hastify). Set Amount = Shortcut Input › Amount, \
                    Merchant = Shortcut Input › Merchant, Card = Shortcut Input › Card.
                    Then add the Hastify widget to your Home Screen.
                    """)
                    .font(.footnote)
                }
            }
            .navigationTitle("Hastify")
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reload() }
        }
    }

    private func reload() {
        spends = SpendStore.today()
    }

    private func delete(at offsets: IndexSet) {
        let shown = Array(spends.reversed())
        SpendStore.delete(ids: Set(offsets.map { shown[$0].id }))
        WidgetCenter.shared.reloadAllTimelines()
        reload()
    }
}
