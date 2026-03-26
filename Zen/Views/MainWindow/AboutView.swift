import SwiftUI
import AppKit

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    @State private var showFeedback = false
    @State private var feedbackSubject = ""
    @State private var feedbackMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon + name
                VStack(spacing: 8) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color(red: 0.95, green: 0.63, blue: 0.21))

                    Text("Zen")
                        .font(.title.weight(.semibold))

                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider().frame(width: 180)

                // Tagline
                Text("A gentle companion that helps you\nstay present while you work.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)

                // How it works
                Text("At regular intervals your screen glows and a quote appears. Drag your cursor to the left edge for present, right for not present. The timer adapts around your rhythm.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .frame(maxWidth: 360)

                // Features
                VStack(alignment: .leading, spacing: 6) {
                    Label("Adaptive & static timer", systemImage: "timer")
                    Label("Mood themes with quotes", systemImage: "quote.closing")
                    Label("Reminders between check-ins", systemImage: "bell")
                    Label("Schedule by day", systemImage: "calendar")
                    Label("Presence analytics", systemImage: "chart.bar")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(spacing: 10) {
                Button {
                    showFeedback = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "envelope")
                            .font(.system(size: 10))
                        Text("Submit bug or feature request")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)

                Text("Made with awareness by Lukas Hammarström")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showFeedback) {
            FeedbackSheet(
                subject: $feedbackSubject,
                message: $feedbackMessage,
                onSend: { sendFeedback() },
                onCancel: {
                    showFeedback = false
                    feedbackSubject = ""
                    feedbackMessage = ""
                }
            )
        }
    }

    private func sendFeedback() {
        let subject = feedbackSubject.trimmingCharacters(in: .whitespaces).isEmpty
            ? "Zen Feedback"
            : "[Zen] \(feedbackSubject.trimmingCharacters(in: .whitespaces))"
        let body = feedbackMessage.trimmingCharacters(in: .whitespaces)
        guard !body.isEmpty else { return }
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        if let url = URL(string: "mailto:lukas@mitthjarta.se?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
        HapticService.playLevelChange()
        showFeedback = false
        feedbackSubject = ""
        feedbackMessage = ""
    }
}
