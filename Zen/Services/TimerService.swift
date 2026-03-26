import Foundation
import Combine

@MainActor
@Observable
final class TimerService {
    var currentInterval: TimeInterval
    var timeRemaining: TimeInterval
    var isRunning = false

    var onTimerFired: (() -> Void)?

    private var timer: Timer?
    private let tickInterval: TimeInterval = 1.0
    private let settings = AppSettings.shared

    private func staticIntervalWithVariance() -> TimeInterval {
        let base = settings.staticInterval
        guard settings.staticVarianceEnabled else { return base }
        let variance = settings.staticVarianceMinutes * 60
        let lo = max(60, base - variance)
        let hi = min(2400, base + variance)
        return Double.random(in: lo...hi)
    }

    init() {
        if AppSettings.shared.timerMode == "static" {
            let interval = AppSettings.shared.staticInterval
            self.currentInterval = interval
            self.timeRemaining = interval
        } else {
            let saved = AppSettings.shared.currentAdaptiveInterval
            let interval = saved > 0 ? saved : AppSettings.shared.baseInterval
            self.currentInterval = interval
            self.timeRemaining = interval
        }
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }

    func pause() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func resume() {
        guard !isRunning else { return }
        isRunning = true
        scheduleTimer()
    }

    func recordPresence(wasPresent: Bool) {
        // Static mode — no adaptive changes, just restart
        guard settings.timerMode == "adaptive" else {
            currentInterval = staticIntervalWithVariance()
            resetTimer()
            return
        }

        if wasPresent {
            currentInterval = min(currentInterval + Constants.intervalStep, Constants.maxInterval)
        } else {
            currentInterval = max(currentInterval - Constants.intervalStep, Constants.minInterval)
        }

        settings.currentAdaptiveInterval = currentInterval
        resetTimer()
    }

    func applyMode() {
        if settings.timerMode == "static" {
            currentInterval = staticIntervalWithVariance()
        } else {
            let saved = settings.currentAdaptiveInterval
            currentInterval = saved > 0 ? saved : settings.baseInterval
        }
        resetTimer()
    }

    func resetToBase() {
        currentInterval = settings.baseInterval
        settings.currentAdaptiveInterval = currentInterval
        resetTimer()
    }

    func resetTimer() {
        timeRemaining = currentInterval
        if isRunning {
            timer?.invalidate()
            scheduleTimer()
        }
    }

    private func scheduleTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.isRunning else { return }
                self.timeRemaining -= self.tickInterval
                if self.timeRemaining <= 0 {
                    self.timeRemaining = 0
                    self.timer?.invalidate()
                    self.timer = nil
                    self.isRunning = false
                    self.onTimerFired?()
                }
            }
        }
    }
}
