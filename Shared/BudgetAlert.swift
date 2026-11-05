import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// What a new tap did to today's daily budget, if anything worth telling you about.
enum BudgetAlert: Equatable {
    /// Crossed 80% of the budget.
    case nearing
    /// Went past the budget.
    case over

    static let nearingFraction = Decimal(string: "0.8")!

    /// Fires once per crossing: only when `before` was on the other side of the line.
    static func check(before: Decimal, after: Decimal, budget: Decimal) -> BudgetAlert? {
        guard budget > 0, after > before else { return nil }
        if before <= budget, after > budget { return .over }
        let line = budget * nearingFraction
        if before < line, after >= line, after <= budget { return .nearing }
        return nil
    }
}

#if canImport(UserNotifications)
/// Local notifications for budget alerts. Safe to call from the app or the widget extension;
/// permission is requested from Settings when the user turns alerts on.
enum BudgetNotifier {
    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    static func check(before: Decimal, after: Decimal) {
        let settings = SettingsStore.load()
        guard settings.notifyBudget, let budget = settings.dailyBudget,
              let alert = BudgetAlert.check(before: before, after: after, budget: budget) else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default
        switch alert {
        case .nearing:
            content.title = "Almost at your budget"
            content.body = "\(after.money) of \(budget.money) spent today."
        case .over:
            content.title = "Over your daily budget"
            content.body = "\(after.money) spent today, \((after - budget).money) over your \(budget.money) budget."
        }
        // One per level per day, so a repeat can't stack up.
        let day = Int(Calendar.current.startOfDay(for: .now).timeIntervalSince1970)
        let id = "budget-\(alert == .over ? "over" : "nearing")-\(day)"
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }
}
#endif
