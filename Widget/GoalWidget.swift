import SwiftUI
import WidgetKit

struct GoalEntry: TimelineEntry {
    let date: Date
    let name: String
    let saved: Decimal
    let target: Decimal
    let accent: Color
    let hasGoal: Bool

    var fraction: Double { target > 0 ? min(1, saved.doubleValue / target.doubleValue) : 0 }
}

struct GoalProvider: TimelineProvider {
    func placeholder(in context: Context) -> GoalEntry {
        GoalEntry(date: .now, name: "Trip", saved: 120, target: 500, accent: AppTheme.violet.color, hasGoal: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (GoalEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<GoalEntry>) -> Void) {
        // Progress only changes when a day completes.
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        completion(Timeline(entries: [current()], policy: .after(midnight)))
    }

    private func current() -> GoalEntry {
        let settings = SettingsStore.load()
        guard let goal = settings.savingsGoal, let budget = settings.dailyBudget, budget > 0 else {
            return GoalEntry(date: .now, name: "", saved: 0, target: 1, accent: settings.theme.color, hasGoal: false)
        }
        let progress = SavingsStats.progress(goal: goal, budget: budget, spends: SpendStore.all())
        return GoalEntry(date: .now, name: goal.name, saved: progress.saved, target: goal.target,
                         accent: settings.theme.color, hasGoal: true)
    }
}

struct GoalWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: GoalEntry

    var body: some View {
        if !entry.hasGoal {
            Text("Set a goal in Hastify").font(.caption)
        } else {
            switch family {
            case .accessoryCircular:
                Gauge(value: entry.fraction) {
                    Image(systemName: "target")
                } currentValueLabel: {
                    Text("\(Int(entry.fraction * 100))%").minimumScaleFactor(0.5)
                }
                .gaugeStyle(.accessoryCircularCapacity)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name).font(.caption)
                    Text("\(entry.saved.shortMoney) / \(entry.target.shortMoney)").font(.headline)
                    Gauge(value: entry.fraction) { EmptyView() }
                        .gaugeStyle(.accessoryLinearCapacity)
                }
            default:
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.name).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    ZStack {
                        BudgetRing(spent: entry.saved, budget: entry.target, tint: entry.accent, lineWidth: 9, redWhenOver: false)
                        Text("\(Int(entry.fraction * 100))%")
                            .font(.system(.headline, design: .rounded).bold())
                    }
                    .frame(maxWidth: .infinity)
                    Text("\(entry.saved.shortMoney) of \(entry.target.shortMoney)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

struct GoalWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SavingsGoal", provider: GoalProvider()) { entry in
            GoalWidgetView(entry: entry)
                .goalWidgetBackground()
        }
        .configurationDisplayName("Savings Goal")
        .description("Progress toward your savings goal.")
        .supportedFamilies([.systemSmall, .accessoryCircular, .accessoryRectangular])
    }
}

private extension View {
    @ViewBuilder
    func goalWidgetBackground() -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(.fill.tertiary, for: .widget)
        } else {
            padding()
        }
    }
}
