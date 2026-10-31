import SwiftUI

struct GoalView: View {
    @ObservedObject var model: SpendModel
    @State private var editing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let goal = model.settings.savingsGoal {
                        if let budget = model.settings.dailyBudget, budget > 0 {
                            goalCard(goal, budget: budget)
                        } else {
                            Card {
                                Text("Set a daily budget in Settings first. Every day you spend less than it counts toward \(goal.name).")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Save by spending less").font(.headline)
                                Text("Each day you stay under your daily budget, the difference goes toward your goal.")
                                    .foregroundStyle(.secondary)
                                Button("Create goal") { Haptics.tap(); editing = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Goal")
            .toolbar {
                if model.settings.savingsGoal != nil {
                    Button("Edit") { editing = true }
                }
            }
            .sheet(isPresented: $editing) {
                GoalEditView(model: model)
            }
        }
    }

    private func goalCard(_ goal: SavingsGoal, budget: Decimal) -> some View {
        let progress = SavingsStats.progress(goal: goal, budget: budget, spends: model.spends)
        return VStack(spacing: 16) {
            Card {
                VStack(spacing: 12) {
                    Text(goal.name).font(.headline)
                    ZStack {
                        BudgetRing(spent: progress.saved, budget: goal.target, tint: Theme.accent, lineWidth: 16, redWhenOver: false, animated: true)
                        VStack(spacing: 2) {
                            Text("\(Int(progress.fraction * 100))%")
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("\(progress.saved.money) of \(goal.target.money)")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding(.vertical, 8)
                    if progress.isDone {
                        Label("Goal reached!", systemImage: "party.popper.fill")
                            .font(.headline)
                            .foregroundStyle(Theme.accent)
                            .onAppear { Haptics.success() }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                StatTile(title: "Left to go", value: progress.remaining.money, icon: "flag.checkered")
                StatTile(
                    title: "Estimated finish",
                    value: progress.eta?.formatted(.dateTime.month(.abbreviated).day()) ?? (progress.isDone ? "Done" : "—"),
                    icon: "calendar"
                )
                StatTile(title: "Streak", value: "\(progress.streak) day\(progress.streak == 1 ? "" : "s")", icon: "flame")
                StatTile(title: "Daily budget", value: budget.money, icon: "gauge.medium")
            }
            Text("Counts completed days since \(goal.startDate.formatted(date: .abbreviated, time: .omitted)). Today is added at midnight.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct GoalEditView: View {
    @ObservedObject var model: SpendModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var targetText = ""
    @State private var confirmDelete = false

    private var target: Decimal? {
        AmountParser.parse(targetText).flatMap { $0 > 0 ? $0 : nil }
    }

    private var existing: SavingsGoal? { model.settings.savingsGoal }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name (e.g. Trip)", text: $name)
                TextField("Target amount", text: $targetText)
                    .keyboardType(.decimalPad)
                if existing != nil {
                    Section {
                        Button("Delete goal", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle(existing == nil ? "New goal" : "Edit goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let target else { return }
                        let title = name.trimmingCharacters(in: .whitespaces)
                        model.updateSettings { settings in
                            // Editing keeps the original start date so progress isn't lost.
                            let start = settings.savingsGoal?.startDate ?? Date()
                            settings.savingsGoal = SavingsGoal(name: title.isEmpty ? "Savings" : title, target: target, startDate: start)
                        }
                        Haptics.success()
                        dismiss()
                    }
                    .disabled(target == nil)
                }
            }
            .confirmationDialog("Delete this goal?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete goal", role: .destructive) {
                    model.updateSettings { $0.savingsGoal = nil }
                    Haptics.warning()
                    dismiss()
                }
            }
            .onAppear {
                if let existing {
                    name = existing.name
                    targetText = "\(existing.target)"
                }
            }
        }
    }
}
