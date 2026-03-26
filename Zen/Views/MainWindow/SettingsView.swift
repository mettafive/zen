import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.appDelegate) private var appDelegate
    @State private var showResetConfirm = false

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

                if settings.timerMode == "adaptive" {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Starts at 5 min, adjusts with each check-in", systemImage: "brain")
                            Label("+3s when present · −3s when not present", systemImage: "arrow.up.arrow.down")
                            Label("Range: 45s – 30 min", systemImage: "ruler")
                            Label("Left edge = Present · Right edge = Not Present", systemImage: "rectangle.lefthalf.filled")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            Text(appDelegate?.timerService.currentInterval.minutesAndSeconds ?? "–")
                                .font(.system(.body, design: .monospaced).monospacedDigit())
                                .foregroundStyle(.primary)
                            Button("Reset") {
                                appDelegate?.timerService.resetToBase()
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .buttonStyle(.plain)
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

            Section("Sound") {
                Toggle("Sound", isOn: $settings.soundEnabled)
                    .onChange(of: settings.soundEnabled) { HapticService.playGeneric() }
                Text("Zen tones when it's time to check in.")
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
                Button("Reset to Defaults") {
                    showResetConfirm = true
                }
                .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert("Reset to Defaults?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) {
                settings.baseInterval = Constants.defaultInterval
                settings.currentAdaptiveInterval = Constants.defaultInterval
                settings.hapticEnabled = true
                settings.soundEnabled = true
                settings.isActive = true
                settings.timerMode = "static"
                settings.staticInterval = 180
                settings.staticVarianceEnabled = true
                settings.staticVarianceMinutes = 1
                settings.remindersEnabled = true
                settings.reminderIntervalMinutes = 3
                appDelegate?.timerService.resetToBase()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let current = appDelegate?.timerService.currentInterval.minutesAndSeconds ?? "–"
            Text("Your timer will reset from \(current) to 3:00. This cannot be undone.")
        }
    }
}
