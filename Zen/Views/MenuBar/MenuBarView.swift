import SwiftUI

struct MenuBarMenu: View {
    @Environment(\.appDelegate) private var appDelegate
    @ObservedObject private var store = MoodStore.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if appDelegate?.needsResume == true {
                MenuBarRow(label: "▶ Resume Zen", color: .green) {
                    appDelegate?.resumeFromInactivity()
                }
                Divider()
            }

            if settings.scheduleEnabled && store.moods.contains(where: { !$0.schedules.isEmpty }) {
                scheduleSection
            } else {
                moodSection
            }

            Divider()

            timerRow

            MenuBarRow(label: "Open Zen") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                for window in NSApplication.shared.windows {
                    if !(window is NSPanel) {
                        window.makeKeyAndOrderFront(nil)
                        break
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(width: 220)
    }

    // MARK: - Schedule section

    @ViewBuilder
    private var scheduleSection: some View {
        Text("Override schedule for 1 hour:")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

        ForEach(store.moods) { (mood: Mood) in
            let isOverriding = store.isOverrideActive && mood.id == store.scheduleOverrideMoodId
            MenuBarMoodRow(mood: mood, trailing: isOverriding ? store.overrideTimeRemaining : nil) {
                HapticService.playGeneric()
                store.overrideSchedule(moodId: mood.id)
            }
        }

        if store.isOverrideActive {
            Divider()
            MenuBarRow(label: "End override", color: .secondary) {
                HapticService.playGeneric()
                store.clearOverride()
            }
        }
    }

    // MARK: - Regular mood section

    @ViewBuilder
    private var moodSection: some View {
        ForEach(store.moods) { (mood: Mood) in
            MenuBarMoodRow(
                mood: mood,
                trailing: mood.id == store.activeMoodId ? "✓" : nil
            ) {
                HapticService.playGeneric()
                store.setActive(id: mood.id)
            }
        }
    }

    // MARK: - Timer row

    @ViewBuilder
    private var timerRow: some View {
        if let timer = appDelegate?.timerService {
            if appDelegate?.edgePillarManager.isListening == true {
                MenuBarRow(label: "Skip vote") {
                    HapticService.playGeneric()
                    appDelegate?.skipVote()
                }
            } else {
                MenuBarRow(label: timer.isRunning ? "Pause" : "Resume") {
                    if timer.isRunning { timer.pause() } else { timer.resume() }
                }
            }
        }
    }
}

// MARK: - Row components

private struct MenuBarRow: View {
    let label: String
    var color: Color = .primary
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isHovered ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }
}

private struct MenuBarMoodRow: View {
    let mood: Mood
    let trailing: String?
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(mood.icon)
                    .font(.system(size: 14))
                Text(mood.name)
                    .font(.system(size: 13))
                Spacer()
                if let t = trailing {
                    Text(t)
                        .font(.system(size: 11, design: .monospaced).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(isHovered ? 0.08 : 0)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
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
