import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SpendModel
    @AppStorage("onboarded") private var onboarded = true
    @State private var confirmClear = false
    @State private var budgetText = ""
    @State private var newRule = ""

    private static let transitPreset = ["MTA", "OMNY", "BART", "TfL", "Clipper", "Transit"]

    private var budgetAmount: Decimal? {
        AmountParser.parse(budgetText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            List {
                budgetSection
                appearanceSection
                ignoredSection
                Section("Setup") {
                    Text("""
                    Shortcuts → Automation → + → Transaction → pick all cards → Run Immediately.
                    Add action "Log Spend" (Hastify). Set Amount = Shortcut Input › Amount, \
                    Merchant = Shortcut Input › Merchant, Card = Shortcut Input › Card.
                    Then add the Hastify widget to your Home Screen or Lock Screen.
                    """)
                    .font(.footnote)
                }
                Section("Test") {
                    Button("Simulate tap") { model.simulateTap(); Haptics.success() }
                    Button("Replay onboarding") { Haptics.tap(); onboarded = false }
                }
                Section("Data") {
                    if let url = model.csvFile() {
                        ShareLink(item: url) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button("Delete all data", role: .destructive) { confirmClear = true }
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog("Delete all logged spending?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Delete all", role: .destructive) { model.clearAll(); Haptics.warning() }
            }
            .onAppear {
                if let budget = model.settings.dailyBudget { budgetText = "\(budget)" }
            }
        }
    }

    private var budgetSection: some View {
        Section {
            HStack {
                TextField("Amount per day", text: $budgetText)
                    .keyboardType(.decimalPad)
                Button("Set") {
                    if let amount = budgetAmount {
                        model.updateSettings { $0.dailyBudget = amount }
                        Haptics.success()
                    }
                }
                .disabled(budgetAmount == nil || budgetAmount == model.settings.dailyBudget)
            }
            if model.settings.dailyBudget != nil {
                Button("Remove budget", role: .destructive) {
                    budgetText = ""
                    model.updateSettings { $0.dailyBudget = nil }
                }
            }
        } header: {
            Text("Daily budget")
        } footer: {
            Text("Shows a progress ring on the widget, Lock Screen, and Overview.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            HStack(spacing: 14) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        Haptics.select()
                        withAnimation(Motion.pop) { model.updateSettings { $0.theme = theme } }
                        model.setIcon(theme)
                    } label: {
                        Circle()
                            .fill(theme.color)
                            .frame(width: 34, height: 34)
                            .overlay {
                                if model.settings.theme == theme {
                                    Image(systemName: "checkmark").font(.footnote.bold()).foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(PressableStyle(scale: 0.88))
                    .accessibilityLabel(theme.name)
                }
            }
            .padding(.vertical, 4)
            Text("Picks the accent color, widget color, and Home Screen icon.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var ignoredSection: some View {
        Section {
            ForEach(model.settings.ignoredMerchants, id: \.self) { rule in
                Text(rule)
            }
            .onDelete { offsets in
                model.updateSettings { $0.ignoredMerchants.remove(atOffsets: offsets) }
            }
            HStack {
                TextField("Add a place", text: $newRule)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Button("Add") {
                    let rule = newRule.trimmingCharacters(in: .whitespaces)
                    guard !rule.isEmpty else { return }
                    Haptics.tap()
                    model.updateSettings { settings in
                        if !settings.ignoredMerchants.contains(where: { $0.caseInsensitiveCompare(rule) == .orderedSame }) {
                            settings.ignoredMerchants.append(rule)
                        }
                    }
                    newRule = ""
                }
                .disabled(newRule.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Button("Add transit presets") {
                model.updateSettings { settings in
                    Haptics.tap()
                    for rule in Self.transitPreset where !settings.ignoredMerchants.contains(rule) {
                        settings.ignoredMerchants.append(rule)
                    }
                }
            }
        } header: {
            Text("Ignored places")
        } footer: {
            Text("Taps whose merchant contains one of these are not logged. Existing history is kept.")
        }
    }
}
