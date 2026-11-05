import SwiftUI
import WidgetKit

struct SpendEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
    let budget: Decimal?
    let accent: Color
    /// Last 7 days, oldest first, for the medium widget.
    let week: [DayTotal]
    /// Preset for the medium widget's "+" button; nil hides it.
    let quickAdd: Decimal?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        let week = [12, 30, 8, 45, 22, 5, 42].enumerated().map { index, amount in
            DayTotal(day: Calendar.current.date(byAdding: .day, value: index - 6, to: .now)!, total: Decimal(amount))
        }
        return SpendEntry(date: .now, total: 42.5, count: 3, budget: 75, accent: AppTheme.violet.color, week: week, quickAdd: 5)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(entry(at: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        // Second entry at midnight so the total and the 7-day window roll over even if nothing reloads the widget.
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        completion(Timeline(entries: [entry(at: .now), entry(at: midnight)], policy: .after(midnight)))
    }

    private func entry(at date: Date) -> SpendEntry {
        let spends = SpendStore.all()
        let settings = SettingsStore.load()
        let today = SpendStats.on(date, spends)
        return SpendEntry(
            date: date,
            total: SpendStats.total(today),
            count: today.count,
            budget: settings.dailyBudget,
            accent: settings.theme.color,
            week: SpendStats.daily(spends, days: 7, now: date),
            quickAdd: settings.quickAddAmount
        )
    }
}

struct SpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendEntry

    var body: some View {
        switch family {
        case .accessoryInline:
            Text("Today \(entry.total.shortMoney)")
        case .accessoryCircular:
            if let budget = entry.budget, budget > 0 {
                Gauge(value: min(1, entry.total.doubleValue / budget.doubleValue)) {
                    Image(systemName: "creditcard")
                } currentValueLabel: {
                    Text(entry.total.shortMoney).minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircularCapacity)
            } else {
                VStack(spacing: 0) {
                    Image(systemName: "creditcard").font(.caption)
                    Text(entry.total.shortMoney)
                        .font(.headline)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .accessoryRectangular:
            VStack(alignment: .center, spacing: 2) {
                Text("Spent today").font(.caption)
                Text(entry.total.money).font(.headline)
                if let budget = entry.budget, budget > 0 {
                    Gauge(value: min(1, entry.total.doubleValue / budget.doubleValue)) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
        case .systemMedium:
            medium
        default:
            small
        }
    }

    private var medium: some View {
        HStack(spacing: 16) {
            small
            VStack(spacing: 6) {
                WeekBars(days: entry.week, tint: entry.accent)
                quickAddButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// iOS 17 interactive widget button; hidden on iOS 16 or until a quick-add amount is set.
    @ViewBuilder
    private var quickAddButton: some View {
        if #available(iOS 17.0, *), let amount = entry.quickAdd, amount > 0 {
            Button(intent: QuickAddSpendIntent()) {
                Label("Add \(amount.shortMoney)", systemImage: "plus")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(entry.accent.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var small: some View {
        VStack(spacing: 4) {
            Text("Today").font(.caption).foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(entry.total.money)
                .font(.system(.title, design: .rounded).bold())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .multilineTextAlignment(.center)
            Spacer(minLength: 0)
            if let budget = entry.budget, budget > 0 {
                HStack(spacing: 8) {
                    BudgetRing(spent: entry.total, budget: budget, tint: entry.accent, lineWidth: 5)
                        .frame(width: 28, height: 28)
                    Text(status(budget))
                        .font(.caption2)
                        .foregroundStyle(entry.total > budget ? Color.red : Color.secondary)
                }
            } else {
                Text("\(entry.count) tap\(entry.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func status(_ budget: Decimal) -> String {
        let diff = budget - entry.total
        return diff >= 0 ? "\(diff.shortMoney) left" : "\((-diff).shortMoney) over"
    }
}

/// Seven small bars, oldest to today, with weekday initials underneath.
struct WeekBars: View {
    let days: [DayTotal]
    let tint: Color

    var body: some View {
        let peak = max(days.map { $0.total.doubleValue }.max() ?? 0, 1)
        VStack(spacing: 4) {
            Text("Last 7 days").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 5) {
                ForEach(days) { day in
                    VStack(spacing: 3) {
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Calendar.current.isDateInToday(day.day) ? tint : tint.opacity(0.4))
                                    .frame(height: max(3, geo.size.height * day.total.doubleValue / peak))
                            }
                        }
                        Text(day.day.formatted(.dateTime.weekday(.narrow)))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private extension View {
    /// iOS 17 requires containerBackground; iOS 16 doesn't have it.
    @ViewBuilder
    func widgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            padding()
        }
    }
}

@main
struct HastifyBundle: WidgetBundle {
    var body: some Widget {
        HastifyWidget()
        GoalWidget()
    }
}

struct HastifyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySpend", provider: Provider()) { entry in
            SpendWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Spent Today")
        .description("Today's Apple Pay tap-to-pay total, with an optional daily budget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
