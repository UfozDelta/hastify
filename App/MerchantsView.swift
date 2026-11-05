import SwiftUI

struct MerchantsView: View {
    @ObservedObject var model: SpendModel
    /// Days to include; 0 means all time.
    @State private var range = 30
    /// 0 = by place, 1 = by category.
    @State private var mode = 0

    var body: some View {
        NavigationStack {
            let spends = range == 0 ? model.spends : SpendStats.lastDays(range, model.spends)
            let merchants = SpendStats.merchants(spends)
            let total = SpendStats.total(spends)
            List {
                Section {
                    Picker("Range", selection: $range) {
                        Text("7 days").tag(7)
                        Text("30 days").tag(30)
                        Text("All time").tag(0)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        Text("Total")
                        Spacer()
                        Text(total.money).bold().monospacedDigit()
                    }
                }
                Section {
                    Picker("Group by", selection: $mode) {
                        Text("Places").tag(0)
                        Text("Categories").tag(1)
                    }
                    .pickerStyle(.segmented)
                }
                if mode == 1 {
                    categorySection(spends, total: total)
                } else {
                    Section("Where it went") {
                        if merchants.isEmpty {
                            Text("No spending in this period").foregroundStyle(.secondary)
                        }
                        ForEach(Array(merchants.enumerated()), id: \.element.id) { index, merchant in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("\(index + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.secondary)
                                        .frame(width: 20, alignment: .leading)
                                    VStack(alignment: .leading) {
                                        Text(merchant.name)
                                        Text("\(merchant.count) tap\(merchant.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text(merchant.total.money).monospacedDigit()
                                }
                                ProgressView(value: share(merchant.total, of: total))
                                    .tint(Theme.accent)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Places")
        }
    }

    private func categorySection(_ spends: [Spend], total: Decimal) -> some View {
        let categories = Categorizer.totals(spends, rules: model.settings.categoryRules)
        return Section {
            if categories.isEmpty {
                Text("No spending in this period").foregroundStyle(.secondary)
            }
            ForEach(categories) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: item.category.icon)
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading) {
                            Text(item.category.name)
                            Text("\(item.count) tap\(item.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.total.money).monospacedDigit()
                    }
                    ProgressView(value: share(item.total, of: total))
                        .tint(Theme.accent)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("By category")
        } footer: {
            Text("Matched from the place name. Add your own rules in Settings.")
        }
    }

    private func share(_ part: Decimal, of whole: Decimal) -> Double {
        whole > 0 ? part.doubleValue / whole.doubleValue : 0
    }
}
