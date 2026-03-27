import AppKit
import Combine
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
    @Published var needsResume = false
    @Published var nextReminderDate: Date?

    private var modelContainer: ModelContainer?
    private var bodyReminderTimer: Timer?
    private var lastActivityDate = Date()
    private var inactivityTimer: Timer?
    private let inactivityThreshold: TimeInterval = 3 * 60 * 60 // 3 hours
    private var healthTimer: Timer?
    private var settingsCancellables = Set<AnyCancellable>()
    private var voteTutorialManager: VoteTutorialManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        CrashReporter.install()
        CrashReporter.sendPendingReport()
        setupModelContainer()
        wireServices()

        if AppSettings.shared.onboardingComplete {
            startAllServices()
        }
        startHealthCheck()
        observeReminderSettings()

        // Track activity for auto-pause
        startInactivityTracker()
    }

    @objc private func handleWake() {
        Task { @MainActor in
            restoreAfterSleep()
        }
    }

    @objc private func handleBecomeActive() {
        Task { @MainActor in
            restoreAfterSleep()
        }
    }

    private func restoreAfterSleep() {
        // Dismiss any stale overlays
        edgePillarManager.stopListening()
        breathGlowManager.dismiss()
        toastManager.dismiss()
        votePending = false

        guard AppSettings.shared.onboardingComplete else { return }

        // Check how long we were away
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        if elapsed >= inactivityThreshold {
            // Been away 3+ hours — require manual resume
            timerService.pause()
            topPeekManager.stopListening()
            pauseBodyReminders()
            needsResume = true
        } else {
            // Short sleep — force restart the timer (old timer is dead after sleep)
            timerService.pause()
            timerService.resume()
            topPeekManager.startListening()
            scheduleNextBodyReminder()
            lastActivityDate = Date()
        }
    }

    // MARK: - Inactivity Tracking

    private func startInactivityTracker() {
        // Check every 10 minutes
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 600, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.needsResume, !self.edgePillarManager.isListening else { return }
                let elapsed = Date().timeIntervalSince(self.lastActivityDate)
                if elapsed >= self.inactivityThreshold {
                    self.timerService.pause()
                    self.topPeekManager.stopListening()
                    self.pauseBodyReminders()
                    self.edgePillarManager.stopListening()
                    self.breathGlowManager.dismiss()
                    self.toastManager.dismiss()
                    self.votePending = false
                    self.needsResume = true
                }
            }
        }

        // Track mouse/keyboard activity
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .keyDown]) { [weak self] _ in
            Task { @MainActor in
                self?.lastActivityDate = Date()
            }
        }
    }

    func resumeFromInactivity() {
        HapticService.playLevelChange()
        needsResume = false
        lastActivityDate = Date()
        timerService.resetTimer()
        timerService.start()
        topPeekManager.startListening()
        scheduleNextBodyReminder()
    }

    // MARK: - Health Check

    private func startHealthCheck() {
        healthTimer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.performHealthCheck() }
        }
    }

    private func performHealthCheck() {
        let settings = AppSettings.shared
        guard !needsResume, !edgePillarManager.isListening else { return }

        // Timer should be running but isn't
        if settings.isActive && !timerService.isRunning {
            print("[Zen] Health: timer was dead, restarting")
            timerService.resetTimer()
            timerService.start()
        }

        // Body reminders should be scheduled but aren't
        if settings.remindersEnabled && settings.isActive && bodyReminderTimer == nil {
            print("[Zen] Health: reminders were dead, restarting")
            scheduleNextBodyReminder()
        }
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

    func startAllServices() {
        if !AppSettings.shared.voteTutorialComplete {
            startVoteTutorial()
            return
        }
        if !AppSettings.shared.appTourComplete {
            // Tour overlay in MainContentView will handle this
            return
        }
        timerService.start()
        startBodyReminders()
        startTopPeek()
    }

    func startTimerAfterTour() {
        timerService.resetToBase()
        timerService.start()
        startBodyReminders()
        startTopPeek()
    }

    private func wireServices() {
        timerService.onTimerFired = { [weak self] in
            guard let self else { return }
            guard AppSettings.shared.isActive else {
                self.timerService.resetToBase()
                self.timerService.start()
                return
            }

            // Play mood's quote sound + haptic
            SoundService.shared.playSound(id: MoodStore.shared.activeMood.quoteSound)
            HapticService.playLevelChange()

            // Screen breathes with a quote in the center
            self.breathGlowManager.breathe(withQuote: true)

            // Pause peek during voting (reminders pause themselves via inVoting check)
            self.topPeekManager.stopListening()

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

    private func startVoteTutorial() {
        topPeekManager.stopListening()
        pauseBodyReminders()

        let tutorial = VoteTutorialManager()
        self.voteTutorialManager = tutorial

        tutorial.onComplete = { [weak self] in
            guard let self else { return }
            self.voteTutorialManager = nil
            // If tour not complete, MainContentView will show it and start timer when done
            guard AppSettings.shared.appTourComplete else { return }
            self.timerService.resetToBase()
            self.timerService.start()
            self.topPeekManager.startListening()
            self.scheduleNextBodyReminder()
        }

        tutorial.start(
            edgePillarManager: edgePillarManager,
            breathGlowManager: breathGlowManager
        )
    }

    func recordVote(wasPresent: Bool) {
        breathGlowManager.dismissGlow()
        let interval = Int(timerService.currentInterval)
        presenceStore?.logEntry(wasPresent: wasPresent, intervalSeconds: interval)
        timerService.recordPresence(wasPresent: wasPresent)
        timerService.start()
        votePending = false
        lastActivityDate = Date()

        // Tell the quote pill to start its countdown
        breathGlowManager.onVoteCompleted()

        // Resume top peek (reminders run independently)
        topPeekManager.startListening()
    }

    func skipVote() {
        edgePillarManager.stopListening()
        breathGlowManager.dismiss()
        timerService.resetTimer()
        timerService.start()
        votePending = false
        lastActivityDate = Date()
        topPeekManager.startListening()
        scheduleNextBodyReminder()
    }

    // MARK: - Body Awareness Reminders

    private func observeReminderSettings() {
        UserDefaults.standard.publisher(for: \.reminderIntervalMinutes)
            .dropFirst()
            .sink { [weak self] _ in self?.restartBodyReminders() }
            .store(in: &settingsCancellables)
        UserDefaults.standard.publisher(for: \.remindersEnabled)
            .dropFirst()
            .sink { [weak self] enabled in
                if enabled { self?.restartBodyReminders() } else { self?.pauseBodyReminders() }
            }
            .store(in: &settingsCancellables)
    }

    private func restartBodyReminders() {
        bodyReminderTimer?.invalidate()
        bodyReminderTimer = nil
        scheduleNextBodyReminder()
    }

    private func startBodyReminders() {
        scheduleNextBodyReminder()
    }

    private func pauseBodyReminders() {
        bodyReminderTimer?.invalidate()
        bodyReminderTimer = nil
        nextReminderDate = nil
        toastManager.dismiss()
    }

    private func scheduleNextBodyReminder() {
        guard AppSettings.shared.remindersEnabled else {
            nextReminderDate = nil
            return
        }
        let delay = AppSettings.shared.reminderIntervalMinutes * 60
        nextReminderDate = Date().addingTimeInterval(delay)
        bodyReminderTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.fireBodyReminder() }
        }
    }

    private func fireBodyReminder() {
        guard AppSettings.shared.isActive, AppSettings.shared.remindersEnabled else {
            scheduleNextBodyReminder()
            return
        }
        // Don't show reminders if:
        // - Within 20s of next check-in
        // - Currently in voting mode (quote/glow showing)
        // - Within 30s of a new timer cycle (just started)
        let tooCloseToEnd = timerService.isRunning && timerService.timeRemaining <= 20
        let inVoting = votePending || edgePillarManager.isListening
        let justStarted = timerService.isRunning && (timerService.currentInterval - timerService.timeRemaining) < 30
        if tooCloseToEnd || inVoting || justStarted {
            // Retry shortly instead of waiting a full interval
            bodyReminderTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.fireBodyReminder() }
            }
            return
        }
        SoundService.shared.playSound(id: MoodStore.shared.activeMood.reminderSound)
        toastManager.showBodyReminder()
        scheduleNextBodyReminder()
    }
}

extension UserDefaults {
    @objc var reminderIntervalMinutes: Double {
        double(forKey: "reminderIntervalMinutes")
    }
    @objc var remindersEnabled: Bool {
        bool(forKey: "remindersEnabled")
    }
}
