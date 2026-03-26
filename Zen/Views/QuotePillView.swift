import SwiftUI

enum PillTextPhase: Hashable {
    case quote
    case breathe
    case present
    case none
}

@MainActor
class QuotePillController: ObservableObject {
    @Published var isVisible = false
    @Published var pillScale: CGFloat = 1.0
    @Published var shadowOpacity: CGFloat = 1.0
    @Published var textPhase: PillTextPhase = .none
    @Published var breathLineProgress: CGFloat = 0
    @Published var breathLineVisible = false

    private var lineTimer: Timer?
    private var onCompleteCallback: (() -> Void)?

    // MARK: - Entrance

    func show() {
        pillScale = 0.1
        isVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            withAnimation(.spring(response: 0.54, dampingFraction: 0.8)) {
                self.pillScale = 1.0
                self.isVisible = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.72) {
            withAnimation(.easeOut(duration: 0.6)) {
                self.textPhase = .quote
            }
        }
    }

    // MARK: - Countdown

    func startCountdown(onComplete: @escaping () -> Void) {
        onCompleteCallback = onComplete

        breathLineProgress = 0
        breathLineVisible = true
        startLineAnimation(from: 0, to: 1, duration: 3.5) {
            withAnimation(.easeOut(duration: 0.6)) {
                self.textPhase = .none
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                withAnimation(.easeOut(duration: 0.6)) {
                    self.textPhase = .breathe
                }
                self.startLineAnimation(from: 1, to: 0, duration: 2.4) {
                    withAnimation(.easeOut(duration: 0.6)) {
                        self.textPhase = .none
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                        withAnimation(.easeOut(duration: 0.6)) {
                            self.textPhase = .present
                        }
                        self.startLineAnimation(from: 0, to: 1, duration: 2.4) {
                            withAnimation(.easeOut(duration: 0.6)) {
                                self.textPhase = .none
                            }
                            self.breathLineVisible = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.54) {
                                self.close()
                            }
                        }
                    }
                }
            }
        }
    }

    private func startLineAnimation(from: CGFloat, to: CGFloat, duration: TimeInterval, onDone: @escaping () -> Void) {
        lineTimer?.invalidate()
        breathLineProgress = from
        let tick: TimeInterval = 1.0 / 30.0
        let step = CGFloat(tick / duration) * (to > from ? 1 : -1)

        lineTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.breathLineProgress += step
                if (step > 0 && self.breathLineProgress >= to) || (step < 0 && self.breathLineProgress <= to) {
                    self.breathLineProgress = to
                    self.lineTimer?.invalidate()
                    self.lineTimer = nil
                    onDone()
                }
            }
        }
    }

    // MARK: - Close

    private func close() {
        // Fade shadow first
        withAnimation(.easeIn(duration: 0.25)) {
            shadowOpacity = 0
        }

        // Then scale + fade the pill
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.42)) {
                self.isVisible = false
                self.pillScale = 0.6
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            self.pillScale = 1.0
            self.shadowOpacity = 1.0
            self.onCompleteCallback?()
            self.onCompleteCallback = nil
        }
    }

    func dismiss() {
        lineTimer?.invalidate()
        lineTimer = nil
        isVisible = false
        pillScale = 1.0
        shadowOpacity = 1.0
        textPhase = .none
        breathLineVisible = false
    }
}

// MARK: - View

struct QuotePillView: View {
    let text: String
    @ObservedObject var controller: QuotePillController

    private var displayText: String {
        switch controller.textPhase {
        case .quote: return text
        case .breathe: return "Take a breath, feel your body"
        case .present: return "Let's stay present"
        case .none: return ""
        }
    }

    private var textVisible: Bool {
        controller.textPhase != .none
    }

    var body: some View {
        HStack {
            Spacer()
            ZenPillView(
                isVisible: controller.isVisible,
                pillScale: controller.pillScale,
                shadowOpacity: controller.shadowOpacity,
                lineProgress: controller.breathLineProgress,
                lineVisible: controller.breathLineVisible,
                showShimmer: true
            ) {
                // Hidden text — always in layout, drives the width
                Text(text)
                    .font(ZenPillStyle.textFont)
                    .lineLimit(1)
                    .padding(.horizontal, 32)
                    .opacity(0)

                // Visible text — always rendered, opacity animated directly
                Text(displayText)
                    .font(ZenPillStyle.textFont)
                    .foregroundStyle(ZenPillStyle.textColor)
                    .lineLimit(1)
                    .opacity(textVisible ? 1 : 0)
                    .animation(.easeInOut(duration: 0.6), value: textVisible)
                    .animation(.easeInOut(duration: 0.6), value: displayText)
            }
            .fixedSize(horizontal: true, vertical: false)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
