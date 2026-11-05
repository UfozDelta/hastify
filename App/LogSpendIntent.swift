import AppIntents
import WidgetKit

/// Called by the Shortcuts "Transaction" automation on every Wallet tap-to-pay.
struct LogSpendIntent: AppIntent {
    static let title: LocalizedStringResource = "Log Spend"
    static let description = IntentDescription("Adds a Wallet tap-to-pay transaction to today's total.")
    static let openAppWhenRun = false

    // String, not Double: numeric input from the Transaction trigger has been flaky.
    @Parameter(title: "Amount")
    var amount: String

    @Parameter(title: "Merchant")
    var merchant: String?

    @Parameter(title: "Card")
    var card: String?

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let before = SpendStore.total(SpendStore.today())
        switch SpendStore.log(amountText: amount, merchant: merchant, card: card) {
        case .ignored:
            return .result(value: "Skipped: ignored place")
        case .invalidAmount:
            return .result(value: "Skipped: no amount in \"\(amount)\"")
        case .duplicate:
            return .result(value: "Skipped: duplicate tap")
        case .logged(let value):
            BudgetNotifier.check(before: before, after: before + value)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: SpendStore.total(SpendStore.today()).formatted(.currency(code: Currency.code)))
    }
}
