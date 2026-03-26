import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    var onComplete: () -> Void
    @Environment(\.appDelegate) private var appDelegate

    @State private var step = 0
    @State private var appeared = false
    @State private var launchAtLogin = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            // Background fills entire window
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Group {
                    switch step {
                    case 0: welcomeStep
                    case 1: timerStep
                    case 2: edgeStep
                    case 3: repeatStep
                    default: EmptyView()
                    }
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 12)

                Spacer()

                // Progress dots (only for steps 0-3)
                HStack(spacing: 12) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i <= step ? Color.primary : Color.primary.opacity(0.15))
                            .frame(width: 7, height: 7)
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.4), value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color(red: 0.95, green: 0.63, blue: 0.21))

            Text("Welcome to Zen")
                .font(.system(size: 26, weight: .medium, design: .serif))

            Text("A mindfulness companion that sits\nquietly with you while you work.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var timerStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "timer")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("A gentle chime")
                .font(.system(size: 26, weight: .medium, design: .serif))

            Text("At regular intervals, a soft sound plays —\na quiet invitation to check in with yourself.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var edgeStep: some View {
        VStack(spacing: 20) {
            HStack(spacing: 40) {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.left.to.line")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)
                    Text("Present")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.blue)
                }
                VStack(spacing: 8) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 28))
                        .foregroundStyle(.red)
                    Text("Not present")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
            }

            Text("Hover your mouse")
                .font(.system(size: 26, weight: .medium, design: .serif))

            Text("When the chime sounds, slide your mouse\nto the left or right edge of the screen.\nHold for 2 seconds. That's it.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var repeatStep: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Repeat")
                .font(.system(size: 26, weight: .medium, design: .serif))

            Text("A chime, a check-in, and back to your work.\nOver time, you'll notice more and react less.")
                .font(.system(size: 14, design: .serif))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                Toggle(isOn: $launchAtLogin) {
                    Text("Start Zen when I log in")
                        .font(.system(size: 13))
                }
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) {
                    setLaunchAtLogin(launchAtLogin)
                }

                Button {
                    AppSettings.shared.onboardingComplete = true
                    appDelegate?.startAllServices()
                    onComplete()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(red: 0.95, green: 0.63, blue: 0.21))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 10)
        }
        .onAppear { animateIn() }
    }

    // MARK: - Helpers

    private func nextButton(_ title: String) -> some View {
        Button {
            appeared = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                step += 1
            }
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private func animateIn() {
        appeared = false
        withAnimation(.easeOut(duration: 0.4).delay(0.05)) {
            appeared = true
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[Zen] Launch at login error: \(error)")
        }
    }
}
