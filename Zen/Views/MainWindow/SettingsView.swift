import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.appDelegate) private var appDelegate
    @State private var isTimerRevealed = false
    @State private var revealTask: Task<Void, Never>?
    @State private var holdProgress: CGFloat = 0
    @State private var holdTimer: Timer?

    var body: some View {
        Form {
            Section("Current Timer") {
                if let timer = appDelegate?.timerService {
                    if isTimerRevealed {
                        HStack {
                            Label("Next check-in", systemImage: "timer")
                            Spacer()
                            Text(timer.timeRemaining.minutesAndSeconds)
                                .font(.title3.monospacedDigit())
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Label("Current interval", systemImage: "arrow.trianglehead.2.clockwise")
                            Spacer()
                            Text(timer.currentInterval.humanReadable)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Label("Streak", systemImage: "flame")
                            Spacer()
                            Text("\(timer.consecutivePresent)/2")
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            let isVoting = appDelegate?.edgePillarManager.isListening == true
                            Label(
                                "Status",
                                systemImage: timer.isRunning ? "circle.fill" : isVoting ? "hand.raised.fill" : "pause.circle.fill"
                            )
                            .foregroundStyle(timer.isRunning ? .green : isVoting ? .blue : .orange)
                            Spacer()
                            Text(timer.isRunning ? "Running" : isVoting ? "Voting" : "Paused")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 8) {
                            HStack {
                                Label("Timer hidden", systemImage: "eye.slash")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("Hold anywhere to reveal")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }

                            // Loading bar
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.accentColor.opacity(0.3))
                                    .frame(width: geo.size.width * holdProgress, height: 3)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 3)
                            .opacity(holdProgress > 0 ? 1 : 0)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    guard holdTimer == nil else { return }
                                    startHoldTimer()
                                }
                                .onEnded { _ in
                                    cancelHoldTimer()
                                }
                        )
                    }
                }
            }

            Section("Timer Mode") {
                Picker("Mode", selection: $settings.timerMode) {
                    Text("Adaptive").tag("adaptive")
                    Text("Static").tag("static")
                }
                .pickerStyle(.segmented)
                .help("Adaptive learns your rhythm over time. Static repeats at a fixed interval you choose.")
                .onChange(of: settings.timerMode) {
                    HapticService.playGeneric()
                    appDelegate?.timerService.applyMode()
                }

                if settings.timerMode == "adaptive" {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Starts at 45s, grows when you stay present", systemImage: "brain")
                        Label("+15s after 2 present · −15s on not present", systemImage: "arrow.up.arrow.down")
                        Label("Range: 45s – 30 min", systemImage: "ruler")
                        Label("Left edge = Present · Right edge = Not Present", systemImage: "rectangle.lefthalf.filled")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                } else {
                    Picker("Interval", selection: $settings.staticInterval) {
                        ForEach(1...30, id: \.self) { minute in
                            Text("\(minute) min").tag(Double(minute * 60))
                        }
                    }
                    .help("Check-ins will repeat at this exact interval, every time.")
                    .onChange(of: settings.staticInterval) {
                        appDelegate?.timerService.applyMode()
                    }

                    Toggle("Variance", isOn: $settings.staticVarianceEnabled)
                        .onChange(of: settings.staticVarianceEnabled) { HapticService.playGeneric() }
                    Text("Adds randomness around the interval so it feels less robotic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if settings.staticVarianceEnabled {
                        Picker("+/−", selection: $settings.staticVarianceMinutes) {
                            Text("± 1 min").tag(1.0)
                            Text("± 2 min").tag(2.0)
                            Text("± 3 min").tag(3.0)
                            Text("± 5 min").tag(5.0)
                        }
                        .onChange(of: settings.staticVarianceMinutes) {
                            appDelegate?.timerService.applyMode()
                        }

                        let baseMin = Int(settings.staticInterval / 60)
                        let varMin = Int(settings.staticVarianceMinutes)
                        let lo = max(1, baseMin - varMin)
                        let hi = min(40, baseMin + varMin)
                        Text("Range: \(lo) – \(hi) min")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section("Feedback") {
                Toggle("Haptic feedback", isOn: $settings.hapticEnabled)
                    .onChange(of: settings.hapticEnabled) { HapticService.playGeneric() }
                Text("A gentle tap when it's time to check in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Sound", isOn: $settings.soundEnabled)
                    .onChange(of: settings.soundEnabled) { HapticService.playGeneric() }
                Text("Zen tones when it's time to check in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Mindfulness quotes", isOn: $settings.showQuotes)
                    .onChange(of: settings.showQuotes) { HapticService.playGeneric() }
                Text("A quote appears after each check-in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Quote & reminder order", selection: $settings.quoteOrder) {
                    Text("Random").tag("random")
                    Text("Sequential").tag("sequential")
                }
                .help("Random shuffles quotes. Sequential goes through them in order.")
            }

            Section("Reminders") {
                Toggle("Reminders", isOn: $settings.remindersEnabled)
                    .onChange(of: settings.remindersEnabled) { HapticService.playGeneric() }
                Text("Gentle nudges between check-ins from your active mood.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.remindersEnabled {
                    Picker("Every", selection: $settings.reminderIntervalMinutes) {
                        Text("1 min").tag(1.0)
                        Text("2 min").tag(2.0)
                        Text("3 min").tag(3.0)
                        Text("4 min").tag(4.0)
                        Text("5 min").tag(5.0)
                    }
                    .help("How often reminders appear between check-ins.")
                }
            }

            Section {
                Toggle("Active", isOn: $settings.isActive)
                    .onChange(of: settings.isActive) { HapticService.playGeneric() }
                Text("When disabled, no check-ins occur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button("Reset to Defaults") {
                    settings.baseInterval = Constants.defaultInterval
                    settings.currentAdaptiveInterval = Constants.defaultInterval
                    settings.consecutivePresent = 0
                    settings.hapticEnabled = true
                    settings.soundEnabled = true
                    settings.showQuotes = true
                    settings.isActive = true
                    settings.quoteOrder = "random"
                    settings.timerMode = "adaptive"
                    settings.staticInterval = 300
                    settings.staticVarianceEnabled = false
                    settings.staticVarianceMinutes = 1
                    settings.remindersEnabled = true
                    settings.reminderIntervalMinutes = 3
                    appDelegate?.timerService.resetToBase()
                }
                .foregroundStyle(.red)
            }

            Section("Debug") {
                Button("Set timer to 5 seconds") {
                    guard let timer = appDelegate?.timerService else { return }
                    timer.pause()
                    timer.timeRemaining = 5
                    timer.start()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startHoldTimer() {
        holdProgress = 0
        let tick: TimeInterval = 1.0 / 60.0
        let duration: TimeInterval = 0.5

        holdTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { _ in
            DispatchQueue.main.async {
                holdProgress += CGFloat(tick / duration)
                if holdProgress >= 1.0 {
                    holdProgress = 0
                    cancelHoldTimer()
                    withAnimation(.easeOut(duration: 0.2)) {
                        isTimerRevealed = true
                    }
                    revealTask?.cancel()
                    revealTask = Task {
                        try? await Task.sleep(for: .seconds(10))
                        guard !Task.isCancelled else { return }
                        withAnimation(.easeIn(duration: 0.3)) {
                            isTimerRevealed = false
                        }
                    }
                }
            }
        }
    }

    private func cancelHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = nil
        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 0
        }
    }
}
