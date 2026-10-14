import SwiftUI
import WidgetKit

struct SpendEntry: TimelineEntry {
    let date: Date
    let total: Decimal
    let count: Int
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SpendEntry {
        SpendEntry(date: .now, total: 42.5, count: 3)
    }

    func getSnapshot(in context: Context, completion: @escaping (SpendEntry) -> Void) {
        completion(current())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SpendEntry>) -> Void) {
        // Zero entry at midnight so the total resets even if nothing reloads the widget.
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
        let entries = [current(), SpendEntry(date: midnight, total: 0, count: 0)]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }

    private func current() -> SpendEntry {
        let today = SpendStore.today()
        return SpendEntry(date: .now, total: SpendStore.total(today), count: today.count)
    }
}

struct SpendWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SpendEntry

    var body: some View {
        let total = entry.total.formatted(.currency(code: Currency.code))
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text("Spent today").font(.caption)
                Text(total).font(.headline)
            }
        default:
            VStack(alignment: .leading, spacing: 4) {
                Text("Today").font(.caption).foregroundStyle(.secondary)
                Text(total)
                    .font(.system(.title, design: .rounded).bold())
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Spacer()
                Text("\(entry.count) tap\(entry.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
struct HastifyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TodaySpend", provider: Provider()) { entry in
            SpendWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Spent Today")
        .description("Today's Apple Pay tap-to-pay total.")
        .supportedFamilies([.systemSmall, .accessoryRectangular])
    }
}
