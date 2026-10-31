import SwiftUI

struct ContentView: View {
    @StateObject private var model = SpendModel()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarded") private var onboarded = false

    var body: some View {
        TabView {
            OverviewView(model: model)
                .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
            MerchantsView(model: model)
                .tabItem { Label("Places", systemImage: "storefront") }
            HistoryView(model: model)
                .tabItem { Label("History", systemImage: "list.bullet") }
            GoalView(model: model)
                .tabItem { Label("Goal", systemImage: "target") }
            SettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(model.settings.theme.color)
        .fullScreenCover(isPresented: Binding(get: { !onboarded }, set: { onboarded = !$0 })) {
            OnboardingView(model: model) { onboarded = true }
        }
        .onAppear(perform: model.reload)
        .onActive(scenePhase, perform: model.reload)
    }
}

private extension View {
    /// Runs `action` whenever the scene becomes active. iOS 17 deprecated the one-parameter
    /// onChange; iOS 16 only has it.
    @ViewBuilder
    func onActive(_ phase: ScenePhase, perform action: @escaping () -> Void) -> some View {
        if #available(iOS 17.0, *) {
            onChange(of: phase) { _, new in
                if new == .active { action() }
            }
        } else {
            onChange(of: phase) { new in
                if new == .active { action() }
            }
        }
    }
}
