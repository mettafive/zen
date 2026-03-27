import SwiftUI
import SwiftData

@main
struct ZenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var updater = UpdaterService()

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: PresenceEntry.self)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainContentView(appDelegate: appDelegate)
                .environment(\.appDelegate, appDelegate)
                .frame(minWidth: 580, minHeight: 575)
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 920, height: 635)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updater.checkForUpdates()
                }
                .disabled(!updater.canCheckForUpdates)
            }
        }

        MenuBarExtra("Zen", systemImage: "drop.fill") {
            MenuBarMenu()
                .environment(\.appDelegate, appDelegate)
        }
        .menuBarExtraStyle(.window)
    }
}
