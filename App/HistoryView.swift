import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: SpendModel
    @State private var showingAdd = false

    private var sections: [(day: Date, spends: [Spend])] {
        let cal = Calendar.current
        return Dictionary(grouping: model.spends) { cal.startOfDay(for: $0.date) }
            .map { (day: $0.key, spends: $0.value) }
            .sorted { $0.day > $1.day }
    }

    var body: some View {
        NavigationStack {
            List {
                if model.spends.isEmpty {
                    Text("No taps yet").foregroundStyle(.secondary)
                }
                ForEach(sections, id: \.day) { section in
                    Section {
                        ForEach(section.spends) { spend in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(spend.merchant.isEmpty ? "Unknown" : spend.merchant)
                                    Text(subtitle(for: spend))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(spend.amount.money).monospacedDigit()
                            }
                        }
                        .onDelete { offsets in
                            model.delete(ids: Set(offsets.map { section.spends[$0].id }))
                        }
                    } header: {
                        HStack {
                            Text(section.day.dayLabel)
                            Spacer()
                            Text(SpendStats.total(section.spends).money).monospacedDigit()
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSpendView(model: model)
            }
        }
    }

    private func subtitle(for spend: Spend) -> String {
        let time = spend.date.formatted(date: .omitted, time: .shortened)
        return spend.card.isEmpty ? time : "\(time) · \(spend.card)"
    }
}

/// Manual entry for cash or missed taps.
struct AddSpendView: View {
    @ObservedObject var model: SpendModel
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var merchant = ""
    @State private var date = Date()

    private var amount: Decimal? {
        AmountParser.parse(amountText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Amount", text: $amountText)
                    .keyboardType(.decimalPad)
                TextField("Merchant", text: $merchant)
                DatePicker("When", selection: $date, in: ...Date.now)
            }
            .navigationTitle("Add spend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount {
                            model.add(Spend(date: date, amount: amount, merchant: merchant, card: "Manual"))
                            dismiss()
                        }
                    }
                    .disabled(amount == nil)
                }
            }
        }
    }
}
