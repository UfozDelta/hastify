import SwiftUI
import WidgetKit

struct SpendEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
    let budget: Decimal?
    let accent: Color
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        SpendEntry(date: .now, total: 42.5, count: 3, budget: 75, accent: AppTheme.violet.color)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        // Zero entry at midnight so the total resets even if nothing reloads the widget.
        let now = current()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        let reset = SpendEntry(date: midnight, total: 0, count: 0, budget: now.budget, accent: now.accent)
        completion(Timeline(entries: [now, reset], policy: .after(midnight)))
    }

    private func current() -> SpendEntry {
        let today = SpendStore.today()
        let settings = SettingsStore.load()
        return SpendEntry(
            date: .now,
            total: SpendStore.total(today),
            count: today.count,
            budget: settings.dailyBudget,
            accent: settings.theme.color
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
                    Text(entry.total.shortMoney).font(.headline).minimumScaleFactor(0.5)
                }
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("Spent today").font(.caption)
                Text(entry.total.money).font(.headline)
                if let budget = entry.budget, budget > 0 {
                    Gauge(value: min(1, entry.total.doubleValue / budget.doubleValue)) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            }
        default:
            small
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Today").font(.caption).foregroundStyle(.secondary)
            Text(entry.total.money)
                .font(.system(.title, design: .rounded).bold())
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Spacer()
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func status(_ budget: Decimal) -> String {
        let diff = budget - entry.total
        return diff >= 0 ? "\(diff.shortMoney) left" : "\((-diff).shortMoney) over"
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
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
