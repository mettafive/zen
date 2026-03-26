import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.appDelegate) private var appDelegate
    @State private var showResetSettings = false
    @State private var showResetEverything = false

    var body: some View {
        Form {
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

                Text(settings.timerMode == "adaptive"
                    ? "Time between bells grows when you're present, shortens when you're not."
                    : "Bells ring at a fixed interval you choose.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.timerMode == "adaptive" {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Starts at 5 min and adapts as you go", systemImage: "brain")
                            Label("Grows when you're present, shortens when you're not", systemImage: "arrow.up.arrow.down")
                            Label("Ranges between 45 seconds and 30 minutes", systemImage: "ruler")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(appDelegate?.timerService.currentInterval.minutesAndSeconds ?? "–")
                                .font(.system(.body, design: .monospaced).monospacedDigit())
                                .foregroundStyle(.primary)
                            if settings.currentAdaptiveInterval != Constants.defaultInterval {
                                Button("Reset") {
                                    appDelegate?.timerService.resetToBase()
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .buttonStyle(.plain)
                            }
                        }
                    }
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

                    Text("A small variance is added so the bell never feels robotic.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Sound") {
                Toggle("Sound", isOn: $settings.soundEnabled)
                    .onChange(of: settings.soundEnabled) { HapticService.playGeneric() }
                Text("Mute all sounds from Zen.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            Section("Debug") {
                Button("Set timer to 5 seconds") {
                    guard let timer = appDelegate?.timerService else { return }
                    timer.pause()
                    timer.timeRemaining = 5
                    timer.start()
                }
            }

            Section {
                Button("Show Onboarding") {
                    settings.onboardingComplete = false
                }
            }

            Section {
                Button("Reset Settings") {
                    showResetSettings = true
                }

                Button("Reset Everything") {
                    showResetEverything = true
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Reset Settings?", isPresented: $showResetSettings) {
            Button("Reset Settings", role: .destructive) {
                resetSettings()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset timer, sound, haptics, and reminders back to defaults. Your moods and schedules will not be affected.")
        }
        .alert("Reset Everything?", isPresented: $showResetEverything) {
            Button("Reset Everything", role: .destructive) {
                resetSettings()
                // Moods — wipe all including custom
                MoodStore.shared.moods = DefaultMoods.all
                MoodStore.shared.activeMoodId = DefaultMoods.buddhaId
                MoodStore.shared.save()
                // Schedule
                settings.scheduleEnabled = false
                settings.inactiveBehavior = "00000000-0000-0000-0000-000000000001"
                settings.scheduleOnboardingComplete = false
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will erase all custom moods, schedules, and restore default moods. All settings will be reset. This cannot be undone.")
        }
    }

    private func resetSettings() {
        settings.baseInterval = Constants.defaultInterval
        settings.currentAdaptiveInterval = Constants.defaultInterval
        settings.hapticEnabled = true
        settings.soundEnabled = true
        settings.isActive = true
        settings.timerMode = "adaptive"
        settings.staticInterval = 180
        settings.staticVarianceEnabled = true
        settings.staticVarianceMinutes = 1
        settings.remindersEnabled = true
        settings.reminderIntervalMinutes = 3
        settings.glowTheme = "orange"
        settings.quoteOrder = "random"
        appDelegate?.timerService.resetToBase()
    }
}
