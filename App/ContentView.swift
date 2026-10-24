import SwiftUI

struct ContentView: View {
    @StateObject private var model = SpendModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            OverviewView(model: model)
                .tabItem { Label("Overview", systemImage: "chart.bar.fill") }
            MerchantsView(model: model)
                .tabItem { Label("Places", systemImage: "storefront") }
            HistoryView(model: model)
                .tabItem { Label("History", systemImage: "list.bullet") }
            SettingsView(model: model)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Theme.accent)
        .onAppear(perform: model.reload)
        .onChange(of: scenePhase) { phase in
            if phase == .active { model.reload() }
        }
    }
}
