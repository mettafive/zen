import SwiftUI
import AppKit

struct MainContentView: View {
    @ObservedObject private var appDelegate: AppDelegate
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTab = 0
    @State private var linkCopied = false
    @State private var showCopiedToast = false

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
    }

    var body: some View {
        if !settings.onboardingComplete {
            OnboardingView {
                // Onboarding done
            }
        } else if appDelegate.votePending {
            VoteView { wasPresent in
                appDelegate.recordVote(wasPresent: wasPresent)
            }
        } else {
            VStack(spacing: 0) {
                topBar
                Divider()

                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem {
                            Label("Home", systemImage: "house")
                        }
                        .tag(0)

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .tag(1)

                    AnalyticsView()
                        .tabItem {
                            Label("Analytics", systemImage: "chart.bar")
                        }
                        .tag(2)

                    AboutView()
                        .tabItem {
                            Label("About", systemImage: "info.circle")
                        }
                        .tag(3)
                }
            }
            .frame(minWidth: 500, minHeight: 400)
            .overlay(alignment: .bottom) {
                if showCopiedToast {
                    Text("Link copied")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                        )
                        .padding(.bottom, 12)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .overlay {
                if appDelegate.needsResume {
                    WelcomeBackOverlay {
                        appDelegate.resumeFromInactivity()
                    }
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: appDelegate.needsResume)
            .background {
                // Hidden buttons for Cmd+1/2/3/4 tab switching
                VStack {
                    Button("") { selectedTab = 0 }
                        .keyboardShortcut("1", modifiers: .command)
                    Button("") { selectedTab = 1 }
                        .keyboardShortcut("2", modifiers: .command)
                    Button("") { selectedTab = 2 }
                        .keyboardShortcut("3", modifiers: .command)
                    Button("") { selectedTab = 3 }
                        .keyboardShortcut("4", modifiers: .command)
                }
                .opacity(0)
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            // Left: drop icon + name
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color(red: 0.95, green: 0.63, blue: 0.21))
                    Text("Zen")
                        .font(.headline)
                }
                Spacer()
            }

            // Center: pause/play + timer
            HStack(spacing: 8) {
                PausePlayButton(isRunning: appDelegate.timerService.isRunning) {
                    HapticService.playGeneric()
                    if appDelegate.timerService.isRunning {
                        appDelegate.timerService.pause()
                    } else {
                        appDelegate.timerService.resume()
                    }
                }

                Button {
                    HapticService.playGeneric()
                    selectedTab = 1
                } label: {
                    HStack(spacing: 4) {
                        Text(appDelegate.timerService.timeRemaining.minutesAndSeconds)
                            .font(.system(.body, design: .monospaced).monospacedDigit())
                            .foregroundStyle(appDelegate.timerService.isRunning ? .secondary : .tertiary)
                        Text("/")
                            .font(.caption)
                            .foregroundStyle(.quaternary)
                        Text(appDelegate.timerService.currentInterval.minutesAndSeconds)
                            .font(.system(.caption, design: .monospaced).monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
            }

            // Right: share
            HStack {
                Spacer()
                ShareButton {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("Check out Zen — a mindfulness companion for Mac\nhttps://mettafive.github.io/zen", forType: .string)
                    HapticService.playGeneric()
                    withAnimation(.easeOut(duration: 0.2)) { showCopiedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.easeIn(duration: 0.3)) { showCopiedToast = false }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

// MARK: - Pause/Play Button

private struct PausePlayButton: View {
    let isRunning: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(isHovered ? 1.0 : 0.4)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .animation(.easeInOut(duration: 0.15), value: isRunning)
        .onHover { h in isHovered = h }
        .help(isRunning ? "Pause timer" : "Resume timer")
    }
}

// MARK: - Share Button

private struct ShareButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 11))
                Text("Share")
                    .font(.system(size: 12))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.1), value: isHovered)
        .onHover { h in isHovered = h }
        .help("Copy Zen link to share with a friend")
    }
}

// MARK: - Welcome Back Overlay

private struct WelcomeBackOverlay: View {
    let onResume: () -> Void
    @ObservedObject private var store = MoodStore.shared
    @State private var isHovered = false
    @State private var appeared = false

    private var randomQuote: String {
        store.activeMood.quotes.randomElement() ?? "Be present."
    }

    var body: some View {
        ZStack {
            // Frosted glass background
            Rectangle()
                .fill(.ultraThinMaterial)

            VStack(spacing: 24) {
                Spacer()

                Text(store.activeMood.icon)
                    .font(.system(size: 48))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text("Welcome back")
                    .font(.title.weight(.light))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Text(randomQuote)
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)

                Spacer().frame(height: 8)

                Button {
                    onResume()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12))
                        Text("Start again")
                            .font(.body.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.green)
                    )
                }
                .buttonStyle(.plain)
                .scaleEffect(isHovered ? 1.04 : 1.0)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 10)
                .animation(.easeOut(duration: 0.1), value: isHovered)
                .onHover { h in isHovered = h }

                Spacer()
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeOut(duration: 0.6).delay(0.1)) {
                appeared = true
            }
        }
    }
}
