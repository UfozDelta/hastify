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
        guard let value = AmountParser.parse(amount), value > 0 else {
            return .result(value: "Skipped: no amount in \"\(amount)\"")
        }
        SpendStore.add(Spend(date: .now, amount: value, merchant: merchant ?? "", card: card ?? ""))
        WidgetCenter.shared.reloadAllTimelines()
        return .result(value: SpendStore.total(SpendStore.today()).formatted(.currency(code: Currency.code)))
    }
}
