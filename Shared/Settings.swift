import SwiftUI

/// Accent themes. Each one also has a matching alternate app icon (`AppIcon-<name>`).
enum AppTheme: String, Codable, CaseIterable, Identifiable {
    case violet, ocean, mint, sunset, rose

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var color: Color {
        switch self {
        case .violet: return Color(red: 0.55, green: 0.36, blue: 0.96)
        case .ocean: return Color(red: 0.20, green: 0.52, blue: 0.92)
        case .mint: return Color(red: 0.13, green: 0.70, blue: 0.52)
        case .sunset: return Color(red: 0.96, green: 0.52, blue: 0.16)
        case .rose: return Color(red: 0.93, green: 0.30, blue: 0.55)
        }
    }

    /// Alternate icon name for `setAlternateIconName`; nil is the primary (violet) icon.
    var iconName: String? { self == .violet ? nil : "AppIcon-\(name)" }
}

struct Settings: Codable, Equatable {
    var dailyBudget: Decimal?
    var ignoredMerchants: [String] = []
    var theme: AppTheme = .violet
    var savingsGoal: SavingsGoal?

    /// Case-insensitive substring match, so "MTA" also catches "MTA*NYCT PAYGO".
    func isIgnored(_ merchant: String) -> Bool {
        let name = merchant.lowercased()
        return ignoredMerchants.contains { rule in
            let rule = rule.trimmingCharacters(in: .whitespaces).lowercased()
            return !rule.isEmpty && name.contains(rule)
        }
    }
}

/// JSON file next to spends.json in the shared App Group container.
enum SettingsStore {
    private static let fileName = "settings.json"

    static func load() -> Settings {
        guard let data = try? Data(contentsOf: SpendStore.fileURL(named: fileName)) else { return Settings() }
        return (try? JSONDecoder().decode(Settings.self, from: data)) ?? Settings()
    }

    static func save(_ settings: Settings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: SpendStore.fileURL(named: fileName), options: .atomic)
    }
}

/// Progress ring for spent vs. budget; turns red once over.
struct BudgetRing: View {
    let spent: Decimal
    let budget: Decimal
    var tint: Color
    var lineWidth: CGFloat = 8
    /// Budgets turn red when exceeded; goals (more is better) pass false.
    var redWhenOver = true
    /// Fills from empty on appear. App only: widgets render once and never fire onAppear.
    var animated = false

    @State private var drawn = false

    private var progress: Double {
        budget > 0 ? min(1, spent.doubleValue / budget.doubleValue) : 0
    }

    private var shown: Double { animated && !drawn ? 0 : progress }

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: shown)
                .stroke(redWhenOver && spent > budget ? Color.red : tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(animated ? .spring(response: 0.5, dampingFraction: 1) : nil, value: shown)
        }
        .onAppear { drawn = true }
    }
}

extension Decimal {
    /// Whole units only, for tight spaces like Lock Screen widgets.
    var shortMoney: String { formatted(.currency(code: Currency.code).precision(.fractionLength(0))) }
}

extension Settings {
    /// "$12.00 left" / "$3.50 over", or nil with no budget.
    func budgetStatus(spent: Decimal) -> String? {
        guard let budget = dailyBudget else { return nil }
        let diff = budget - spent
        return diff >= 0 ? "\(diff.money) left" : "\((-diff).money) over"
    }
}
