import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if step == 0 {
                welcomeStep
            } else if step == 1 {
                howItWorksStep
            }

            Spacer()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<2) { i in
                    Circle()
                        .fill(i == step ? Color.primary : Color.primary.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom, 30)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("Welcome to Zen")
                .font(.system(size: 24, weight: .medium, design: .serif))

            Text("A gentle companion that helps you\nstay present while you work.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                withAnimation { step = 1 }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
    }

    private var howItWorksStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "bell.badge")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("How it works")
                .font(.system(size: 24, weight: .medium, design: .serif))

            VStack(alignment: .leading, spacing: 12) {
                Label("A gentle chime plays at regular intervals", systemImage: "speaker.wave.2")
                Label("Slide mouse to the left edge → Present", systemImage: "arrow.left.to.line")
                    .foregroundStyle(.blue)
                Label("Slide mouse to the right edge → Not Present", systemImage: "arrow.right.to.line")
                    .foregroundStyle(.red)
                Label("Hold for 2 seconds. That's it.", systemImage: "hand.raised")
                Label("Your interval adapts to your natural rhythm", systemImage: "waveform.path")
                    .foregroundStyle(.secondary)
            }
            .font(.system(size: 13, design: .serif))

            Button("Get Started") {
                AppSettings.shared.onboardingComplete = true
                onComplete()
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 10)
        }
    }
}
