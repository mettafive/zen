import SwiftUI

// Menu-style content (used with default .menu MenuBarExtra style)
struct MenuBarMenu: View {
    @Environment(\.appDelegate) private var appDelegate
    @ObservedObject private var store = MoodStore.shared

    var body: some View {
        ForEach(store.moods) { (mood: Mood) in
            Button {
                HapticService.playGeneric()
                store.setActive(id: mood.id)
            } label: {
                if mood.id == store.activeMoodId {
                    Text("\(mood.icon) \(mood.name) ✓")
                } else {
                    Text("\(mood.icon) \(mood.name)")
                }
            }
        }

        Divider()

        Button(appDelegate?.timerService.isRunning == true ? "Pause" : "Resume") {
            guard let timer = appDelegate?.timerService else { return }
            if timer.isRunning { timer.pause() } else { timer.resume() }
        }

        Button("Open Zen") {
            NSApplication.shared.activate(ignoringOtherApps: true)
            for window in NSApplication.shared.windows {
                if !(window is NSPanel) {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
            }
        }

    }
}

private struct AppDelegateKey: EnvironmentKey {
    static let defaultValue: AppDelegate? = nil
}

extension EnvironmentValues {
    var appDelegate: AppDelegate? {
        get { self[AppDelegateKey.self] }
        set { self[AppDelegateKey.self] = newValue }
    }
}
