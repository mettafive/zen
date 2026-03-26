import SwiftUI
import AppKit

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

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
                Link(destination: URL(string: "https://wa.me/46706195510")!) {
                    HStack(spacing: 5) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 10))
                        Text("Send bug report to Lukas on WhatsApp")
                            .font(.caption)
                    }
                    .foregroundStyle(.tertiary)
                }

                Text("Made with awareness by Lukas Hammarström")
                    .font(.caption)
                    .foregroundStyle(.quaternary)
            }
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

}
