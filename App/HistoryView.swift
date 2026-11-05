import SwiftUI

struct HistoryView: View {
    @ObservedObject var model: SpendModel
    @State private var showingAdd = false
    @State private var editing: Spend?

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
                            Button {
                                Haptics.tap()
                                editing = spend
                            } label: {
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
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete { offsets in
                            Haptics.tap(.rigid)
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
                    Haptics.tap()
                    showingAdd = true
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddSpendView(model: model)
            }
            .sheet(item: $editing) { spend in
                EditSpendView(model: model, spend: spend)
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
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let amount {
                            model.add(Spend(date: date, amount: amount, merchant: merchant, card: "Manual"))
                            Haptics.success()
                            dismiss()
                        }
                    }
                    .disabled(amount == nil)
                }
            }
        }
    }
}

/// Fix the amount, merchant or time of a logged spend (a wrong Shortcut value, a missed tap's time).
struct EditSpendView: View {
    @ObservedObject var model: SpendModel
    let spend: Spend
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var merchant: String
    @State private var date: Date

    init(model: SpendModel, spend: Spend) {
        self.model = model
        self.spend = spend
        _amountText = State(initialValue: "\(spend.amount)")
        _merchant = State(initialValue: spend.merchant)
        _date = State(initialValue: spend.date)
    }

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
                if !spend.card.isEmpty {
                    LabeledContent("Card", value: spend.card)
                }
            }
            .navigationTitle("Edit spend")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneButton()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount else { return }
                        var updated = spend
                        updated.amount = amount
                        updated.merchant = merchant.trimmingCharacters(in: .whitespaces)
                        updated.date = date
                        model.update(updated)
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(amount == nil)
                }
            }
        }
    }
}
