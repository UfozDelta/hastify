import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: SpendModel
    @AppStorage("onboarded") private var onboarded = true
    @State private var confirmClear = false
    @State private var budgetText = ""
    @State private var newRule = ""
    @State private var newKeyword = ""
    @State private var newCategory = SpendCategory.coffee

    private static let transitPreset = ["MTA", "OMNY", "BART", "TfL", "Clipper", "Transit"]

    private var budgetAmount: Decimal? {
        AmountParser.parse(budgetText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        NavigationStack {
            List {
                budgetSection
                periodBudgetSection
                alertsSection
                quickAddSection
                appearanceSection
                categorySection
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
            .keyboardDoneButton()
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

    private var periodBudgetSection: some View {
        Section {
            AmountRow(title: "Weekly budget", current: model.settings.weeklyBudget) { amount in
                model.updateSettings { $0.weeklyBudget = amount }
            }
            AmountRow(title: "Monthly budget", current: model.settings.monthlyBudget) { amount in
                model.updateSettings { $0.monthlyBudget = amount }
            }
        } header: {
            Text("Weekly & monthly budget")
        } footer: {
            Text("Optional. Each shows its own progress ring on Overview.")
        }
    }

    private var alertsSection: some View {
        Section {
            Toggle("Budget alerts", isOn: Binding(
                get: { model.settings.notifyBudget },
                set: { on in
                    guard on else {
                        model.updateSettings { $0.notifyBudget = false }
                        return
                    }
                    Task { @MainActor in
                        let granted = await BudgetNotifier.requestPermission()
                        model.updateSettings { $0.notifyBudget = granted }
                    }
                }
            ))
        } footer: {
            Text("Get a notification when a tap takes you past 80% of your daily budget, and again when you go over. Needs a daily budget.")
        }
    }

    private var quickAddSection: some View {
        Section {
            AmountRow(title: "Quick-add amount", current: model.settings.quickAddAmount) { amount in
                model.updateSettings { $0.quickAddAmount = amount }
            }
        } header: {
            Text("Widget quick add")
        } footer: {
            Text("The medium widget gets a + button that logs this amount as a cash spend (iOS 17 or later).")
        }
    }

    private var categorySection: some View {
        Section {
            ForEach(model.settings.categoryRules, id: \.self) { rule in
                Label {
                    Text("\(rule.keyword) → \(rule.category.name)")
                } icon: {
                    Image(systemName: rule.category.icon)
                }
            }
            .onDelete { offsets in
                model.updateSettings { $0.categoryRules.remove(atOffsets: offsets) }
            }
            HStack {
                TextField("Place contains…", text: $newKeyword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                Picker("Category", selection: $newCategory) {
                    ForEach(SpendCategory.allCases) { Text($0.name).tag($0) }
                }
                .labelsHidden()
                Button("Add") {
                    let keyword = newKeyword.trimmingCharacters(in: .whitespaces)
                    guard !keyword.isEmpty else { return }
                    Haptics.tap()
                    model.updateSettings { $0.categoryRules.append(CategoryRule(keyword: keyword, category: newCategory)) }
                    newKeyword = ""
                }
                .buttonStyle(.borderless)
                .disabled(newKeyword.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        } header: {
            Text("Categories")
        } footer: {
            Text("Common places (Starbucks, Target, MTA…) are sorted automatically. Your rules win over those.")
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

/// A decimal-pad row with Set / clear, for optional amount settings.
private struct AmountRow: View {
    let title: String
    let current: Decimal?
    let onSet: (Decimal?) -> Void
    @State private var text = ""

    private var amount: Decimal? {
        AmountParser.parse(text).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        HStack {
            TextField(title, text: $text)
                .keyboardType(.decimalPad)
            Button("Set") {
                guard let amount else { return }
                onSet(amount)
                Haptics.success()
            }
            .buttonStyle(.borderless)
            .disabled(amount == nil || amount == current)
            if current != nil {
                Button {
                    text = ""
                    onSet(nil)
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove \(title)")
            }
        }
        .onAppear {
            if let current { text = "\(current)" }
        }
    }
}
