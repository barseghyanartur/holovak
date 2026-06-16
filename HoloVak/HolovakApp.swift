import SwiftUI

@main
struct HolovakApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .newItem) {
                Button("Reset All Settings…") {
                    AppSettings.shared.reset()
                }
                .keyboardShortcut("r", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .appInfo) {
                Button("About Holovak") {
                    showAboutWindow()
                }
            }
        }
    }
}
