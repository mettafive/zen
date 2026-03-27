import SwiftUI

private let zenOrange = Color(red: 0.95, green: 0.63, blue: 0.21)

struct VoteTutorialOverlayView: View {
    @ObservedObject var manager: VoteTutorialManager

    var body: some View {
        ZStack {
            // Frosted glass background — dims during breathe phase so glow shows through
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .opacity(manager.overlayVisible ? (manager.phase == .breatheQuote ? 0.3 : 1) : 0)
                .animation(.easeInOut(duration: 0.6), value: manager.overlayVisible)
                .animation(.easeInOut(duration: 0.8), value: manager.phase)

            Group {
                switch manager.phase {
                case .countdown:
                    countdownView
                case .breatheQuote:
                    breatheQuoteView
                case .practiceLeft:
                    practiceView(side: .left)
                case .wellDoneLeft:
                    wellDoneView
                case .practiceRight:
                    practiceView(side: .right)
                case .wellDoneRight:
                    finalWellDoneView
                case .complete:
                    EmptyView()
                }
            }
            .opacity(manager.overlayVisible ? 1 : 0)
            .animation(.easeInOut(duration: 0.5), value: manager.overlayVisible)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    enum Side { case left, right }

    // MARK: - Countdown

    private var countdownView: some View {
        VStack(spacing: 20) {
            Text("\(manager.countdownValue)")
                .font(.system(size: 120, weight: .ultraLight, design: .serif))
                .foregroundStyle(.primary.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: manager.countdownValue)
            Text("Your first check-in is coming...")
                .font(.system(size: 22, weight: .light, design: .serif))
                .foregroundStyle(.secondary)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 8)).animation(.easeOut(duration: 0.5)),
            removal: .opacity.animation(.easeIn(duration: 0.4))
        ))
    }

    // MARK: - Breathe + Quote

    private var breatheQuoteView: some View {
        // Mostly empty — the real glow + quote pill play behind the dimmed frosted glass
        // Just a subtle hint at the bottom
        VStack {
            Spacer()
            Text("This is what a check-in feels like")
                .font(.system(size: 15, weight: .light, design: .serif))
                .foregroundStyle(.secondary.opacity(0.8))
                .padding(.bottom, 80)
        }
        .transition(.asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.6)),
            removal: .opacity.animation(.easeIn(duration: 0.3))
        ))
    }

    // MARK: - Practice

    private func practiceView(side: Side) -> some View {
        let isLeft = side == .left
        return ZStack {
            // Edge glow
            EdgeGlow(side: side)

            // Center text
            VStack(spacing: 14) {
                Text(isLeft ? "Move your mouse to the left edge" : "Now try the right edge")
                    .font(.system(size: 31, weight: .light, design: .serif))
                    .foregroundStyle(.primary.opacity(0.8))
                Text(isLeft
                    ? "Hold it there for a few seconds — this means you were present"
                    : "Hold it there — this means you were not present")
                    .font(.system(size: 18, weight: .light, design: .serif))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .offset(y: 8)).animation(.easeOut(duration: 0.5)),
                removal: .opacity.animation(.easeIn(duration: 0.3))
            ))

            // Animated arrow near edge
            EdgeArrow(side: side)
                .transition(.asymmetric(
                    insertion: .opacity.animation(.easeOut(duration: 0.4).delay(0.2)),
                    removal: .opacity.animation(.easeIn(duration: 0.25))
                ))
        }
    }

    // MARK: - Well done

    private var wellDoneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(zenOrange)
            Text("Well done")
                .font(.system(size: 31, weight: .light, design: .serif))
                .foregroundStyle(.primary.opacity(0.8))
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.easeOut(duration: 0.5)),
            removal: .opacity.animation(.easeIn(duration: 0.3))
        ))
    }

    private var finalWellDoneView: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52, weight: .ultraLight))
                .foregroundStyle(zenOrange)
            Text("Well done")
                .font(.system(size: 31, weight: .light, design: .serif))
                .foregroundStyle(.primary.opacity(0.8))
            Text("This fullscreen guide won't appear again.\nZen runs quietly in the background.")
                .font(.system(size: 14, weight: .light, design: .serif))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.top, 4)
        }
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.95)).animation(.easeOut(duration: 0.5)),
            removal: .opacity.animation(.easeIn(duration: 0.3))
        ))
    }
}

// MARK: - Edge glow

private struct EdgeGlow: View {
    let side: VoteTutorialOverlayView.Side
    @State private var glowOpacity: CGFloat = 0

    private var isLeft: Bool { side == .left }

    var body: some View {
        HStack {
            if !isLeft { Spacer() }

            LinearGradient(
                colors: [
                    zenOrange.opacity(0.25),
                    zenOrange.opacity(0.08),
                    .clear
                ],
                startPoint: isLeft ? .leading : .trailing,
                endPoint: isLeft ? .trailing : .leading
            )
            .frame(width: 120)
            .opacity(glowOpacity)

            if isLeft { Spacer() }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8)) {
                glowOpacity = 1
            }
        }
    }
}

// MARK: - Animated edge arrow

private struct EdgeArrow: View {
    let side: VoteTutorialOverlayView.Side
    @State private var offset: CGFloat = 0
    @State private var appeared = false

    private var isLeft: Bool { side == .left }

    var body: some View {
        HStack {
            if !isLeft { Spacer() }

            Image(systemName: isLeft ? "arrow.left" : "arrow.right")
                .font(.system(size: 54, weight: .light))
                .foregroundStyle(zenOrange)
                .shadow(color: zenOrange.opacity(0.5), radius: 10, x: 0, y: 2)
                .shadow(color: .black.opacity(0.18), radius: 5, x: 0, y: 1)
                .offset(x: isLeft ? -offset : offset)
                .opacity(appeared ? 1 : 0)

            if isLeft { Spacer() }
        }
        .padding(.horizontal, 50)
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                appeared = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                offset = 20
            }
        }
    }
}
