#if canImport(AppIntents)
import AppIntents
import WidgetKit

/// Backs the "+ cash" button on the medium widget (iOS 17 interactive widgets).
/// Compiled into both the app and the widget extension, which is what interactive widgets need.
struct QuickAddSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Quick Add Cash Spend"
    static let description = IntentDescription("Adds your preset cash amount to today's total.")

    func perform() async throws -> some IntentResult {
        guard let amount = SettingsStore.load().quickAddAmount, amount > 0 else { return .result() }
        let before = SpendStore.total(SpendStore.today())
        // Not SpendStore.log: tapping twice on purpose must count twice, so no duplicate check.
        SpendStore.add(Spend(date: .now, amount: amount, merchant: "Cash", card: "Quick add"))
        BudgetNotifier.check(before: before, after: before + amount)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
#endif
