import SwiftUI
import ServiceManagement

private let zenOrange = Color(red: 0.91, green: 0.57, blue: 0.23)
private let zenOrangeBg = Color(red: 0.996, green: 0.953, blue: 0.902)

struct OnboardingView: View {
    var onComplete: () -> Void
    @Environment(\.appDelegate) private var appDelegate

    @State private var step = 0
    @State private var appeared = false
    @State private var launchAtLogin = false

    private let totalSteps = 4

    var body: some View {
        ZStack {
            Color(nsColor: NSColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1))
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
                .blur(radius: appeared ? 0 : 3)
                .offset(y: appeared ? 0 : 10)

                Spacer()

                // Clickable progress dots
                HStack(spacing: 16) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .fill(i == step ? zenOrange.opacity(0.8) : Color.primary.opacity(0.08))
                            .frame(width: i == step ? 7 : 6, height: i == step ? 7 : 6)
                            .animation(.easeInOut(duration: 0.4), value: step)
                            .onTapGesture { goToStep(i) }
                    }
                }
                .padding(.bottom, 36)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Image(systemName: "drop.fill")
                .font(.system(size: 40))
                .foregroundStyle(zenOrange)
                .shadow(color: zenOrange.opacity(0.2), radius: 12, y: 4)

            Text("Zen")
                .font(.system(size: 32, weight: .ultraLight, design: .serif))
                .tracking(-1.5)

            Text("A gentle companion that helps you\nstay present while you work.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var timerStep: some View {
        VStack(spacing: 18) {
            iconCircle("timer")

            Text("A gentle chime")
                .font(.system(size: 22, weight: .light, design: .serif))
                .tracking(-0.5)

            Text("At regular intervals, a soft sound plays —\na quiet invitation to check in with yourself.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var edgeStep: some View {
        VStack(spacing: 18) {
            HStack(spacing: 36) {
                VStack(spacing: 6) {
                    Image(systemName: "arrow.left.to.line")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(zenOrange)
                    Text("Present")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(zenOrange)
                }
                VStack(spacing: 6) {
                    Image(systemName: "arrow.right.to.line")
                        .font(.system(size: 20, weight: .light))
                        .foregroundStyle(Color(white: 0.45))
                    Text("Not present")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color(white: 0.45))
                }
            }

            Text("Hover your mouse")
                .font(.system(size: 22, weight: .light, design: .serif))
                .tracking(-0.5)

            Text("When the chime sounds, slide your mouse\nto the left or right edge of the screen.\nHold for 2 seconds. That's it.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            nextButton("Continue")
        }
        .onAppear { animateIn() }
    }

    private var repeatStep: some View {
        VStack(spacing: 18) {
            iconCircle("arrow.trianglehead.2.counterclockwise")

            Text("Repeat")
                .font(.system(size: 22, weight: .light, design: .serif))
                .tracking(-0.5)

            Text("A chime, a check-in, and back to your work.\nOver time, you'll notice more and react less.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            VStack(spacing: 14) {
                Toggle(isOn: $launchAtLogin) {
                    Text("Start Zen when I log in")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .toggleStyle(.checkbox)
                .onChange(of: launchAtLogin) {
                    setLaunchAtLogin(launchAtLogin)
                }

                primaryButton("Get Started") {
                    AppSettings.shared.onboardingComplete = true
                    appDelegate?.startAllServices()
                    onComplete()
                }
            }
            .padding(.top, 4)
        }
        .onAppear { animateIn() }
    }

    // MARK: - Components

    private func tagPill(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .medium))
            .tracking(1.2)
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                Capsule().stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
    }

    private func iconCircle(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .light))
            .foregroundStyle(zenOrange)
            .frame(width: 48, height: 48)
            .background(zenOrangeBg)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func nextButton(_ title: String) -> some View {
        Button { goToStep(step + 1) } label: {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.04))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func goToStep(_ newStep: Int) {
        guard newStep >= 0 && newStep < totalSteps && newStep != step else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            appeared = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            step = newStep
        }
    }

    private func animateIn() {
        appeared = false
        withAnimation(.easeOut(duration: 0.55).delay(0.1)) {
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
