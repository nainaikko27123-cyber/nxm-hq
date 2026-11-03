import SwiftUI

@main
struct IdolStudioApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup("NXM HQ") {
            ContentView()
                .environment(appState)
                // Company theme: black surfaces, white text, red accents.
                .preferredColorScheme(.dark)
                .tint(Theme.red)
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 780)
        .commands { IdolCommands(appState: appState) }
    }
}
