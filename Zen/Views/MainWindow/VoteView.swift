import SwiftUI

struct VoteView: View {
    var onVote: (Bool) -> Void

    @State private var leftProgress: CGFloat = 0
    @State private var rightProgress: CGFloat = 0
    @State private var leftTimer: Timer?
    @State private var rightTimer: Timer?
    @State private var voted = false

    private let fillDuration: TimeInterval = 2.0
    private let tickInterval: TimeInterval = 1.0 / 60.0

    var body: some View {
        HStack(spacing: 0) {
            // LEFT — Present
            VotePillar(
                label: "Present",
                icon: "checkmark",
                fillProgress: leftProgress,
                color: Color(red: 0.2, green: 0.7, blue: 0.9),
                isActive: leftProgress > 0
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !voted, leftTimer == nil else { return }
                        cancelRight()
                        startLeft()
                    }
                    .onEnded { _ in
                        if !voted { cancelLeft() }
                    }
            )

            Divider()
                .frame(width: 1)
                .background(Color.white.opacity(0.1))

            // RIGHT — Not Present
            VotePillar(
                label: "Not Present",
                icon: "xmark",
                fillProgress: rightProgress,
                color: Color(red: 0.9, green: 0.4, blue: 0.3),
                isActive: rightProgress > 0
            )
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !voted, rightTimer == nil else { return }
                        cancelLeft()
                        startRight()
                    }
                    .onEnded { _ in
                        if !voted { cancelRight() }
                    }
            )
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(Color.black.opacity(0.95))
    }

    private func startLeft() {
        leftProgress = 0
        HapticService.playAlignment()
        leftTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                let prev = leftProgress
                leftProgress += CGFloat(tickInterval / fillDuration)
                HapticService.handleBreathProgress(leftProgress, previousProgress: prev)
                if leftProgress >= 1.0 {
                    leftProgress = 1.0
                    completeVote(wasPresent: true)
                }
            }
        }
    }

    private func startRight() {
        rightProgress = 0
        HapticService.playAlignment()
        rightTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { _ in
            DispatchQueue.main.async {
                let prev = rightProgress
                rightProgress += CGFloat(tickInterval / fillDuration)
                HapticService.handleBreathProgress(rightProgress, previousProgress: prev)
                if rightProgress >= 1.0 {
                    rightProgress = 1.0
                    completeVote(wasPresent: false)
                }
            }
        }
    }

    private func cancelLeft() {
        leftTimer?.invalidate()
        leftTimer = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            leftProgress = 0
        }
    }

    private func cancelRight() {
        rightTimer?.invalidate()
        rightTimer = nil
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            rightProgress = 0
        }
    }

    private func completeVote(wasPresent: Bool) {
        leftTimer?.invalidate()
        rightTimer?.invalidate()
        leftTimer = nil
        rightTimer = nil
        voted = true
        HapticService.playLevelChange()
        SoundService.shared.playSelectionSound()
        onVote(wasPresent)
    }
}

struct VotePillar: View {
    var label: String
    var icon: String
    var fillProgress: CGFloat
    var color: Color
    var isActive: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background
                Color.black.opacity(0.01) // hittable

                // Water fill from bottom
                VStack(spacing: 0) {
                    Spacer()
                    Rectangle()
                        .fill(color.opacity(isActive ? 0.5 : 0.15))
                        .frame(height: geo.size.height * fillProgress)
                }

                // Wavy surface on the water
                if fillProgress > 0.01 && fillProgress < 0.99 {
                    WaterSurface(fillLevel: fillProgress, color: color)
                }

                // Label + icon
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 32, weight: .light))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.4))

                    Text(label)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(isActive ? .white : .white.opacity(0.4))

                    if isActive {
                        Text("Hold...")
                            .font(.system(size: 12, weight: .light, design: .serif))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
    }
}

struct WaterSurface: View {
    var fillLevel: CGFloat
    var color: Color

    @State private var wavePhase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let waterTop = geo.size.height * (1 - fillLevel)

            Path { path in
                let steps = 30
                for i in 0...steps {
                    let x = geo.size.width * CGFloat(i) / CGFloat(steps)
                    let wave = sin(CGFloat(i) / CGFloat(steps) * .pi * 4 + wavePhase) * 3
                    let point = CGPoint(x: x, y: waterTop + wave)
                    if i == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            .stroke(color.opacity(0.6), lineWidth: 1.5)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
        }
    }
}
