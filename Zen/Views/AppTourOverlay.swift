import SwiftUI

private let zenOrange = Color(red: 0.95, green: 0.63, blue: 0.21)

struct AppTourOverlay: View {
    @Binding var selectedTab: Int
    let onComplete: () -> Void

    @State private var step = 0
    @State private var barVisible = false
    @State private var glowAmount: CGFloat = 0

    private let steps: [(tab: Int, icon: String, title: String, description: String)] = [
        (0, "house", "Meet your moods",
         "Tap a mood to edit its quotes, reminders, and sounds. Create new ones with +."),
        (1, "gearshape", "Your preferences",
         "Control how often the bell goes off, and switch between adaptive and static timing."),
        (2, "calendar", "Your schedule",
         "Set up a custom schedule so different moods play at different times of day."),
        (3, "chart.bar", "Your progress",
         "See how your presence is doing over time."),
    ]

    private var isLastStep: Bool { step >= steps.count }

    var body: some View {
        ZStack {
            if isLastStep {
                // Final "Are you ready?" — centered fullscreen
                finalView
            } else {
                // Bottom bar over real tab content
                VStack {
                    Spacer()
                    bottomBar
                }
            }
        }
        .onAppear {
            selectedTab = steps[0].tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) { barVisible = true }
                startGlow()
            }
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        let current = steps[step]
        return HStack(spacing: 16) {
            Image(systemName: current.icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(zenOrange)
                .frame(width: 36, height: 36)
                .background(Circle().fill(zenOrange.opacity(0.1)))

            VStack(alignment: .leading, spacing: 3) {
                Text(current.title)
                    .font(.system(size: 14, weight: .medium, design: .serif))
                    .foregroundStyle(.primary)
                Text(current.description)
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            // Progress dots
            HStack(spacing: 5) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i <= step ? zenOrange : Color.primary.opacity(0.12))
                        .frame(width: 5, height: 5)
                }
            }

            Button {
                advance()
            } label: {
                Text("Got it →")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(zenOrange)
                            .shadow(color: zenOrange.opacity(glowAmount * 0.5), radius: 8, y: 2)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 0.75)
                )
        )
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .offset(y: barVisible ? 0 : 80)
        .opacity(barVisible ? 1 : 0)
    }

    // MARK: - Final "Are you ready?"

    private var finalView: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(barVisible ? 1 : 0)
                .animation(.easeInOut(duration: 0.5), value: barVisible)

            VStack(spacing: 24) {
                Image(systemName: "play.fill")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(zenOrange)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(zenOrange.opacity(0.1)))

                Text("Are you ready?")
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .foregroundStyle(.primary)

                VStack(spacing: 8) {
                    Text("Your first check-in will arrive in about 5 minutes.")
                        .font(.system(size: 15, weight: .light, design: .serif))
                        .foregroundStyle(.secondary)
                    Text("When the bell rings, move your cursor to the left edge if you were present, or to the right if you weren't.")
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                }

                Button {
                    withAnimation(.easeIn(duration: 0.3)) { barVisible = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        onComplete()
                    }
                } label: {
                    Text("Start")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(zenOrange)
                                .shadow(color: zenOrange.opacity(0.4), radius: 10, y: 3)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
            .opacity(barVisible ? 1 : 0)
            .offset(y: barVisible ? 0 : 10)
        }
    }

    // MARK: - Navigation

    private func advance() {
        let goingToFinal = step + 1 >= steps.count

        // Slide bar out
        withAnimation(.easeIn(duration: 0.25)) { barVisible = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if goingToFinal {
                // Show final overlay first (barVisible drives its opacity)
                step += 1
                withAnimation(.easeOut(duration: 0.5)) { barVisible = true }
                // Switch tab behind the frosted glass after it's fully opaque
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    selectedTab = 0
                }
            } else {
                step += 1
                selectedTab = steps[step].tab
                withAnimation(.easeOut(duration: 0.5)) { barVisible = true }
            }
        }
    }

    private func startGlow() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            glowAmount = 1
        }
    }
}
