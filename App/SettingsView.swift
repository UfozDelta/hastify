import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SpendModel
    @State private var confirmClear = false

    var body: some View {
        NavigationStack {
            List {
                Section("Setup") {
                    Text("""
                    Shortcuts → Automation → + → Transaction → pick all cards → Run Immediately.
                    Add action "Log Spend" (Hastify). Set Amount = Shortcut Input › Amount, \
                    Merchant = Shortcut Input › Merchant, Card = Shortcut Input › Card.
                    Then add the Hastify widget to your Home Screen.
                    """)
                    .font(.footnote)
                }
                Section("Test") {
                    Button("Simulate tap", action: model.simulateTap)
                }
                Section("Data") {
                    Button("Delete all data", role: .destructive) { confirmClear = true }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all logged spending?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all", role: .destructive, action: model.clearAll)
            }
        }
    }
}
