import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    let timerService = TimerService()
    let toastManager = ToastManager()
    let edgePillarManager = EdgePillarManager()
    let breathGlowManager = BreathGlowManager()
    let topPeekManager = TopPeekManager()
    var presenceStore: PresenceStore?
    @Published var votePending = false

    private var modelContainer: ModelContainer?
    private var bodyReminderTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.install()
        CrashReporter.sendPendingReport()
        setupModelContainer()
        wireServices()
        timerService.start()
        startBodyReminders()
        startTopPeek()
    }

    private func startTopPeek() {
        topPeekManager.getTimeRemaining = { [weak self] in
            self?.timerService.timeRemaining ?? 0
        }
        topPeekManager.startListening()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    private func setupModelContainer() {
        do {
            modelContainer = try ModelContainer(for: PresenceEntry.self)
            if let context = modelContainer?.mainContext {
                presenceStore = PresenceStore(modelContext: context)
            }
        } catch {
            print("[Zen] Failed to create ModelContainer: \(error)")
        }
    }

    private func wireServices() {
        timerService.onTimerFired = { [weak self] in
            guard let self else { return }
            guard AppSettings.shared.isActive else {
                self.timerService.resetToBase()
                self.timerService.start()
                return
            }

            // Play zen chime + haptic
            SoundService.shared.playDrainSound()
            HapticService.playLevelChange()

            // Screen breathes with a quote in the center
            self.breathGlowManager.breathe(withQuote: true)

            // Pause peek + body reminders during voting
            self.topPeekManager.stopListening()
            self.pauseBodyReminders()

            // Start listening for edge interaction (invisible until user goes to edge)
            self.edgePillarManager.startListening()
        }

        edgePillarManager.onVoteRecorded = { [weak self] wasPresent in
            guard let self else { return }
            self.recordVote(wasPresent: wasPresent)
        }

        edgePillarManager.onEdgeEngaged = { [weak self] in
            self?.breathGlowManager.dimGlow()
        }

        edgePillarManager.onEdgeDisengaged = { [weak self] in
            self?.breathGlowManager.scheduleRestoreGlow()
        }
    }

    func recordVote(wasPresent: Bool) {
        breathGlowManager.dismissGlow()
        let interval = Int(timerService.currentInterval)
        presenceStore?.logEntry(wasPresent: wasPresent, intervalSeconds: interval)
        timerService.recordPresence(wasPresent: wasPresent)
        timerService.start()
        votePending = false

        // Tell the quote pill to start its countdown
        breathGlowManager.onVoteCompleted()

        // Resume top peek + body reminders
        topPeekManager.startListening()
        scheduleNextBodyReminder()
    }

    // MARK: - Body Awareness Reminders

    private func startBodyReminders() {
        scheduleNextBodyReminder()
    }

    private func pauseBodyReminders() {
        bodyReminderTimer?.invalidate()
        bodyReminderTimer = nil
        toastManager.dismiss()
    }

    private func scheduleNextBodyReminder() {
        guard AppSettings.shared.remindersEnabled else { return }
        let delay = AppSettings.shared.reminderIntervalMinutes * 60
        bodyReminderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                guard AppSettings.shared.isActive, AppSettings.shared.remindersEnabled else {
                    self.scheduleNextBodyReminder()
                    return
                }
                self.toastManager.showBodyReminder()
                self.scheduleNextBodyReminder()
            }
        }
    }
}
