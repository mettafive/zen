import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.appDelegate) private var appDelegate
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

            Section("Appearance") {
                Picker("Glow theme", selection: $settings.glowTheme) {
                    Text("Orange").tag("orange")
                    Text("White").tag("white")
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.glowTheme) { HapticService.playGeneric() }
                Text("Changes the screen glow and quote pill colors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
}
