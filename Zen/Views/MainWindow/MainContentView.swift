import SwiftUI
import AppKit

struct MainContentView: View {
    @ObservedObject private var appDelegate: AppDelegate
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var store = MoodStore.shared
    @State private var selectedTab = 0
    @State private var linkCopied = false
    @State private var showCopiedToast = false
    @State private var showTip = false
    @State private var tipDismissed = false
    @State private var showAppTour = false
    @State private var tabContentVisible = true

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

                    ScheduleView()
                        .tabItem {
                            Label("Schedule", systemImage: "calendar")
                        }
                        .tag(2)

                    AnalyticsView()
                        .tabItem {
                            Label("History", systemImage: "chart.bar")
                        }
                        .tag(3)

                    AboutView()
                        .tabItem {
                            Label("About", systemImage: "info.circle")
                        }
                        .tag(4)
                }
                .opacity(tabContentVisible ? 1 : 0)
                .onChange(of: selectedTab) {
                    withAnimation(.easeOut(duration: 0.12)) { tabContentVisible = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        store.checkSchedule()
                        withAnimation(.easeIn(duration: 0.15)) { tabContentVisible = true }
                    }
                }
            }
            .frame(minWidth: 580, minHeight: 575)
            .overlay(alignment: .bottomLeading) {
                if showTip && !tipDismissed {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Tip")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer()
                            Button {
                                withAnimation(.easeOut(duration: 0.2)) { tipDismissed = true }
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 24, height: 24)
                                    .contentShape(Rectangle())
                                    .background(
                                        Circle()
                                            .stroke(Color.primary.opacity(0.12), lineWidth: 0.75)
                                            .frame(width: 20, height: 20)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        Text("Move your cursor to the very top of your screen and hold it there. After 3 seconds of vibrations, you'll see when the next bell is due. Only works while the timer is running.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: 280)
                    .background(
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(.ultraThinMaterial)
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.06), radius: 10, y: 3)
                    )
                    .padding(16)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
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
            .overlay {
                if showAppTour {
                    AppTourOverlay(selectedTab: $selectedTab) {
                        AppSettings.shared.appTourComplete = true
                        withAnimation(.easeOut(duration: 0.3)) { showAppTour = false }
                        appDelegate.startTimerAfterTour()
                    }
                }
            }
            .animation(.easeInOut(duration: 0.4), value: showAppTour)
            .onAppear {
                if settings.voteTutorialComplete && !settings.appTourComplete && settings.onboardingComplete {
                    showAppTour = true
                }
            }
            .onChange(of: settings.voteTutorialComplete) {
                if settings.voteTutorialComplete && !settings.appTourComplete {
                    showAppTour = true
                }
            }
            .background {
                if !showAppTour {
                    VStack {
                        Button("") { selectedTab = 0 }
                            .keyboardShortcut("1", modifiers: .command)
                        Button("") { selectedTab = 1 }
                            .keyboardShortcut("2", modifiers: .command)
                        Button("") { selectedTab = 2 }
                            .keyboardShortcut("3", modifiers: .command)
                        Button("") { selectedTab = 3 }
                            .keyboardShortcut("4", modifiers: .command)
                        Button("") { selectedTab = 4 }
                            .keyboardShortcut("5", modifiers: .command)
                    }
                    .opacity(0)
                    .allowsHitTesting(false)
                }
            }
            .task {
                guard !UserDefaults.standard.bool(forKey: "tipShown") else { return }
                guard AppSettings.shared.appTourComplete else { return }
                try? await Task.sleep(for: .seconds(300)) // 5 minutes
                guard !Task.isCancelled else { return }
                UserDefaults.standard.set(true, forKey: "tipShown")
                withAnimation(.easeOut(duration: 0.4)) { showTip = true }
                try? await Task.sleep(for: .seconds(5400)) // auto-dismiss after 90 minutes
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.4)) { tipDismissed = true }
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
                if appDelegate.edgePillarManager.isListening {
                    // Voting in progress — show restart/skip button
                    Button {
                        HapticService.playGeneric()
                        appDelegate.skipVote()
                    } label: {
                        TopBarIconButton(systemName: "arrow.counterclockwise")
                    }
                    .buttonStyle(.plain)
                    .help("Skip vote & restart timer")
                } else {
                    PausePlayButton(isRunning: appDelegate.timerService.isRunning) {
                        HapticService.playGeneric()
                        if appDelegate.timerService.isRunning {
                            appDelegate.timerService.pause()
                        } else {
                            appDelegate.timerService.resume()
                        }
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

                if store.isOverrideActive, let remaining = store.overrideTimeRemaining {
                    OverridePill(remaining: remaining) {
                        store.clearOverride()
                    }
                }
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
        .padding(.vertical, 10)
        .fixedSize(horizontal: false, vertical: true)
        .background(.bar)
    }
}

// MARK: - Pause/Play Button

private struct PausePlayButton: View {
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            TopBarIconButton(systemName: isRunning ? "pause.fill" : "play.fill")
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isRunning)
        .help(isRunning ? "Pause timer" : "Resume timer")
    }
}

private struct TopBarIconButton: View {
    let systemName: String
    @State private var isHovered = false

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .frame(width: 26, height: 26)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(isHovered ? 0.06 : 0))
            )
            .contentShape(Rectangle())
            .opacity(isHovered ? 1.0 : 0.5)
            .animation(.easeOut(duration: 0.1), value: isHovered)
            .onHover { h in isHovered = h }
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

// MARK: - Override Pill

private struct OverridePill: View {
    let remaining: String
    let onClear: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button { onClear() } label: {
            HStack(spacing: 4) {
                if isHovered {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 9, weight: .medium))
                    Text("back to schedule")
                        .font(.system(size: 10))
                } else {
                    Image(systemName: "clock")
                        .font(.system(size: 9))
                    Text(remaining)
                        .font(.system(size: 10, design: .monospaced).monospacedDigit())
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.06))
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { h in isHovered = h }
        .help("Schedule overridden — click to resume")
    }
}
