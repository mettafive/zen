import AppKit

@MainActor
struct HapticService {
    private static let performer = NSHapticFeedbackManager.defaultPerformer

    static func playAlignment() {
        guard AppSettings.shared.hapticEnabled else { return }
        performer.perform(.alignment, performanceTime: .now)
    }

    static func playLevelChange() {
        guard AppSettings.shared.hapticEnabled else { return }
        performer.perform(.levelChange, performanceTime: .now)
    }

    /// Light tap — entering a view, toggling a day, adding an item
    static func playGeneric() {
        guard AppSettings.shared.hapticEnabled else { return }
        performer.perform(.generic, performanceTime: .now)
    }

    /// Steady purr haptic — continuous taps at a fixed rate.
    /// Feels like a gentle vibration the whole time you're holding.
    static func handleBreathProgress(_ progress: CGFloat, previousProgress: CGFloat) {
        guard AppSettings.shared.hapticEnabled else { return }

        // Steady purr — tap every ~0.05 progress (~3 taps per 60fps frame batch)
        let interval: CGFloat = 0.05
        let prevBucket = Int(previousProgress / interval)
        let currBucket = Int(progress / interval)

        if currBucket > prevBucket && progress > 0.01 {
            performer.perform(.alignment, performanceTime: .now)
        }

        // Gentle landing on completion
        if previousProgress < 1.0 && progress >= 1.0 {
            performer.perform(.levelChange, performanceTime: .now)
        }
    }
}
