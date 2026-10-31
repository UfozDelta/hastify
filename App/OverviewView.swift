import SwiftUI
import Charts

struct OverviewView: View {
    @ObservedObject var model: SpendModel
    @State private var range = 7

    private var todaySpends: [Spend] { SpendStats.on(.now, model.spends) }
    private var yesterdaySpends: [Spend] { SpendStats.on(SpendStats.yesterday(), model.spends) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    todayCard.entrance(0)
                    budgetCard.entrance(1)
                    statGrid.entrance(2)
                    chartCard.entrance(3)
                    topMerchantsCard.entrance(4)
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Hastify")
        }
    }

    private var todayCard: some View {
        let today = SpendStats.total(todaySpends)
        let yesterday = SpendStats.total(yesterdaySpends)
        let diff = today - yesterday
        let accent = model.settings.theme.color
        return VStack(alignment: .leading, spacing: 6) {
            Text("Spent today").font(.subheadline.weight(.medium)).opacity(0.8)
            Text(today.money)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .numericText(today.money)
            HStack(spacing: 6) {
                Text("\(todaySpends.count) tap\(todaySpends.count == 1 ? "" : "s")")
                Text("·")
                if yesterdaySpends.isEmpty {
                    Text("nothing yesterday")
                } else {
                    Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\((diff < 0 ? -diff : diff).money) vs yesterday")
                }
            }
            .font(.footnote.weight(.medium))
            .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [accent, accent.deepened()], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .shadow(color: accent.opacity(0.35), radius: 14, y: 8)
    }

    @ViewBuilder
    private var budgetCard: some View {
        if let budget = model.settings.dailyBudget, budget > 0 {
            let spent = SpendStats.total(todaySpends)
            Card {
                HStack(spacing: 16) {
                    BudgetRing(spent: spent, budget: budget, tint: Theme.accent, lineWidth: 10, animated: true)
                        .frame(width: 64, height: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Daily budget").font(.subheadline).foregroundStyle(.secondary)
                        Text(model.settings.budgetStatus(spent: spent) ?? "")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(spent > budget ? Color.red : Color.primary)
                        Text("of \(budget.money)").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statGrid: some View {
        let week = SpendStats.during(.weekOfYear, model.spends)
        let month = SpendStats.during(.month, model.spends)
        let biggest = model.spends.map(\.amount).max() ?? 0
        let perTap = model.spends.isEmpty ? 0 : SpendStats.total(model.spends) / Decimal(model.spends.count)
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
            StatTile(title: "Yesterday", value: SpendStats.total(yesterdaySpends).money, icon: "clock.arrow.circlepath")
            StatTile(title: "Avg / day", value: SpendStats.averagePerDay(model.spends).money, icon: "chart.line.flattrend.xyaxis")
            StatTile(title: "This week", value: SpendStats.total(week).money, icon: "calendar")
            StatTile(title: "This month", value: SpendStats.total(month).money, icon: "calendar.badge.clock")
            StatTile(title: "Avg / tap", value: perTap.money, icon: "creditcard")
            StatTile(title: "Biggest tap", value: biggest.money, icon: "arrow.up.to.line")
        }
    }

    private var chartCard: some View {
        let days = SpendStats.daily(model.spends, days: range)
        let average = SpendStats.average(of: days)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily spending").font(.headline)
                    Spacer()
                    Picker("Range", selection: $range) {
                        Text("7D").tag(7)
                        Text("30D").tag(30)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                Text("Average \(average.money) / day")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Chart {
                    ForEach(days) { day in
                        BarMark(
                            x: .value("Day", day.day, unit: .day),
                            y: .value("Spent", day.total.doubleValue)
                        )
                        .foregroundStyle(Calendar.current.isDateInToday(day.day) ? Theme.accent : Theme.accent.opacity(0.45))
                    }
                    RuleMark(y: .value("Average", average.doubleValue))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundStyle(.secondary)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: range == 7 ? 1 : 7)) { _ in
                        AxisValueLabel(format: range == 7 ? .dateTime.weekday(.narrow) : .dateTime.month(.defaultDigits).day())
                    }
                }
                .frame(height: 180)
            }
        }
    }

    private var topMerchantsCard: some View {
        let top = Array(SpendStats.merchants(model.spends).prefix(3))
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Top places").font(.headline)
                if top.isEmpty {
                    Text("No taps yet").foregroundStyle(.secondary)
                }
                ForEach(top) { merchant in
                    HStack {
                        Text(merchant.name)
                        Spacer()
                        Text(merchant.total.money).monospacedDigit()
                    }
                }
            }
        }
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.title3, design: .rounded).bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }
}
