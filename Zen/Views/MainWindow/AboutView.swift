import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
        VStack(spacing: 20) {
            Spacer(minLength: 40)

            Image(systemName: "drop.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color(red: 0.95, green: 0.63, blue: 0.21))

            Text("Zen")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0")
                .foregroundStyle(.secondary)

            Divider()
                .frame(width: 200)

            VStack(spacing: 8) {
                Text("A gentle companion that helps you")
                Text("stay present while you work.")
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)

            VStack(spacing: 4) {
                Text("How it works")
                    .font(.headline)
                    .padding(.top, 12)

                Text("At regular intervals, your screen glows and a quote appears.")
                Text("Slide your mouse to the left edge for present,")
                Text("or the right edge for not present. Hold for two seconds.")
                Text("The timer adapts — stay present and the interval grows.")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 3) {
                Text("Features")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Adaptive & static timer", systemImage: "timer")
                        Label("Mood themes with quotes", systemImage: "quote.closing")
                        Label("Body awareness reminders", systemImage: "figure.mind.and.body")
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Label("Mood scheduling", systemImage: "calendar.badge.clock")
                        Label("Haptic & sound feedback", systemImage: "hand.tap")
                        Label("Presence analytics", systemImage: "chart.bar")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer()

            Text("Made by Lukas Hammarstr\u{00F6}m")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
