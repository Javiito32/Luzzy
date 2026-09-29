import LuzzyUI
import SwiftUI

@main
struct LuzzyApp: App {
    @State private var app = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(app.settings)
                .environment(app.purchases)
                .environment(\.amountsHidden, app.settings.amountsHidden)
                .tint(LuzzyTheme.accent)
                .task { await app.bootstrap() }
                .onChange(of: scenePhase) { _, phase in
                    app.handleScenePhase(phase)
                }
        }
    }
}
