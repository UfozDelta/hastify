import SwiftUI

/// Shown full screen on first launch; Settings can replay it.
struct OnboardingView: View {
    @ObservedObject var model: SpendModel
    let finish: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0
    @State private var forward = true
    @State private var budgetText = ""

    private let lastPage = 4
    private var accent: Color { model.settings.theme.color }

    private var budgetAmount: Decimal? {
        AmountParser.parse(budgetText).flatMap { $0 > 0 ? $0 : nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch page {
                case 0: welcome
                case 1: howItWorks
                case 2: shortcutSetup
                case 3: personalize
                default: widgetSetup
                }
            }
            // Re-create per page so each page's entrance plays and the slide has a pair to swap.
            .id(page)
            .transition(reduceMotion ? .opacity : pageTransition)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            footer
        }
        .background {
            ZStack(alignment: .top) {
                Color(.systemGroupedBackground)
                LinearGradient(colors: [accent.opacity(0.28), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 340)
            }
            .ignoresSafeArea()
            .animation(Motion.out(0.35), value: model.settings.theme)
        }
        .tint(accent)
    }

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    // MARK: Footer

    private var footer: some View {
        VStack(spacing: 18) {
            HStack(spacing: 6) {
                ForEach(0...lastPage, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? accent : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }
            .animation(Motion.settle, value: page)

            HStack {
                Button("Back") { go(to: page - 1) }
                    .buttonStyle(PressableStyle())
                    .opacity(page > 0 ? 1 : 0)
                    .disabled(page == 0)
                Spacer()
                Button(action: advance) {
                    Text(page == lastPage ? "Get started" : "Next")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [accent, accent.deepened()], startPoint: .top, endPoint: .bottom),
                            in: Capsule()
                        )
                        .shadow(color: accent.opacity(0.35), radius: 10, y: 5)
                }
                .buttonStyle(PressableStyle(scale: 0.94))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func go(to new: Int) {
        guard (0...lastPage).contains(new) else { return }
        forward = new > page
        Haptics.select()
        withAnimation(Motion.out(0.3)) { page = new }
    }

    private func advance() {
        guard page == lastPage else {
            go(to: page + 1)
            return
        }
        if let amount = budgetAmount {
            model.updateSettings { $0.dailyBudget = amount }
        }
        Haptics.success()
        finish()
    }

    // MARK: Pages

    private var welcome: some View {
        OnboardingPage(icon: "wave.3.right.circle.fill", title: "Welcome to Hastify", accent: accent) {
            Text("See what you spend with Apple Pay, right on your Home Screen. Nothing leaves your phone: no bank login, no account.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var howItWorks: some View {
        OnboardingPage(icon: "arrow.triangle.2.circlepath", title: "How it works", accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                step(1, "You tap to pay with Apple Pay.")
                step(2, "A Shortcuts automation sends the amount to Hastify.")
                step(3, "Your widget and charts update.")
            }
            Text("Only in-person Wallet taps are logged. Use the + button in History for cash or anything missed.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var shortcutSetup: some View {
        OnboardingPage(icon: "bolt.fill", title: "Connect Shortcuts", accent: accent) {
            VStack(alignment: .leading, spacing: 12) {
                step(1, "Open Shortcuts → Automation → + → Transaction.")
                step(2, "Pick all your cards, then choose Run Immediately.")
                step(3, "Add the action Log Spend (Hastify).")
                step(4, "Set Amount, Merchant and Card from Shortcut Input.")
            }
            Button {
                Haptics.tap()
                if let url = URL(string: "shortcuts://") { openURL(url) }
            } label: {
                Label("Open Shortcuts", systemImage: "arrow.up.forward.app")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(accent.opacity(0.15), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            Text("Takes about a minute and only needs doing once. These steps are also in Settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var personalize: some View {
        OnboardingPage(icon: "paintpalette.fill", title: "Make it yours", accent: accent) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Daily budget (optional)").font(.subheadline.bold())
                TextField("e.g. 40", text: $budgetText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Text("Adds a progress ring to your widget and unlocks savings goals.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("Color").font(.subheadline.bold())
                HStack(spacing: 14) {
                    ForEach(AppTheme.allCases) { theme in
                        Button {
                            Haptics.select()
                            withAnimation(Motion.pop) { model.updateSettings { $0.theme = theme } }
                        } label: {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 36, height: 36)
                                .overlay {
                                    if model.settings.theme == theme {
                                        Image(systemName: "checkmark")
                                            .font(.footnote.bold())
                                            .foregroundStyle(.white)
                                            .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .scaleEffect(model.settings.theme == theme ? 1.12 : 1)
                        }
                        .buttonStyle(PressableStyle(scale: 0.88))
                        .accessibilityLabel(theme.name)
                    }
                }
            }
        }
    }

    private var widgetSetup: some View {
        OnboardingPage(icon: "square.grid.2x2.fill", title: "Add the widget", accent: accent) {
            VStack(alignment: .leading, spacing: 14) {
                step(1, "Long-press your Home Screen and tap +.")
                step(2, "Search Hastify and add Spent Today.")
                step(3, "Lock Screen too: long-press it, tap Customize, add Hastify.")
            }
            Text("You can change the budget, color, icon and ignored places in Settings anytime.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.footnote.bold())
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(accent, in: Circle())
            Text(text)
        }
    }
}

private struct OnboardingPage<Content: View>: View {
    let icon: String
    let title: String
    let accent: Color
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(
                        LinearGradient(colors: [accent, accent.deepened()], startPoint: .topLeading, endPoint: .bottomTrailing),
                        in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                    )
                    .shadow(color: accent.opacity(0.35), radius: 12, y: 6)
                    .padding(.top, 56)
                    .entrance(0, scale: 0.8)
                Text(title)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .entrance(1)
                VStack(alignment: .leading, spacing: 20) {
                    content
                }
                .entrance(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
