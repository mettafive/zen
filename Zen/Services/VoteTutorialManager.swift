import AppKit
import SwiftUI

@MainActor
final class VoteTutorialManager: ObservableObject {
    enum Phase: Equatable {
        case countdown, breatheQuote, practiceLeft, wellDoneLeft, practiceRight, wellDoneRight, complete
    }

    @Published var phase: Phase = .countdown
    @Published var countdownValue: Int = 10
    @Published var overlayVisible = false

    var onComplete: (() -> Void)?

    private var edgePillarManager: EdgePillarManager?
    private var breathGlowManager: BreathGlowManager?
    private var originalVoteCallback: ((Bool) -> Void)?
    private var countdownTimer: Timer?
    private var panel: NSPanel?

    func start(edgePillarManager: EdgePillarManager, breathGlowManager: BreathGlowManager) {
        self.edgePillarManager = edgePillarManager
        self.breathGlowManager = breathGlowManager
        self.originalVoteCallback = edgePillarManager.onVoteRecorded

        showOverlay()

        // Fade in, then start countdown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.overlayVisible = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.startCountdown()
        }
    }

    // MARK: - Countdown

    private func startCountdown() {
        phase = .countdown
        countdownValue = 10
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.countdownValue -= 1
                if self.countdownValue <= 0 {
                    self.countdownTimer?.invalidate()
                    self.countdownTimer = nil
                    self.beginBreatheQuote()
                }
            }
        }
    }

    // MARK: - Breathe + Quote

    private func beginBreatheQuote() {
        phase = .breatheQuote

        // Hide tutorial overlay so the breathing glow + quote are fully visible
        panel?.alphaValue = 0

        // Show breathing glow + tutorial quote pill (the real animation)
        breathGlowManager?.breathe(withQuote: false)
        breathGlowManager?.showQuotePill(customText: "Here there will be a wonderful quote to inspire you")

        // After 4 seconds, bring overlay back and transition to practice left
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            self.panel?.alphaValue = 1
            self.breathGlowManager?.dismissQuote()
            self.beginPracticeLeft()
        }
    }

    // MARK: - Practice steps

    private func beginPracticeLeft() {
        phase = .practiceLeft
        guard let epm = edgePillarManager else { return }
        epm.allowedSide = .left
        epm.onVoteRecorded = { [weak self] _ in
            self?.handleTutorialVote(nextPhase: .wellDoneLeft)
        }
        // Glow already running from breatheQuote phase
        epm.startListening()
    }

    private func beginPracticeRight() {
        phase = .practiceRight
        guard let epm = edgePillarManager else { return }
        epm.resetFillState()
        epm.allowedSide = .right
        epm.onVoteRecorded = { [weak self] _ in
            self?.handleTutorialVote(nextPhase: .wellDoneRight)
        }
        breathGlowManager?.breathe(withQuote: false)
        epm.startListening()
    }

    private func handleTutorialVote(nextPhase: Phase) {
        edgePillarManager?.stopListening()
        breathGlowManager?.dismissGlow()
        breathGlowManager?.dismissQuote()
        phase = nextPhase

        let delay: TimeInterval = nextPhase == .wellDoneRight ? 3.5 : 2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self else { return }
            switch nextPhase {
            case .wellDoneLeft:
                self.beginPracticeRight()
            case .wellDoneRight:
                self.finishTutorial()
            default:
                break
            }
        }
    }

    // MARK: - Finish

    private func finishTutorial() {
        phase = .complete
        overlayVisible = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            guard let self else { return }
            self.edgePillarManager?.allowedSide = nil
            self.edgePillarManager?.onVoteRecorded = self.originalVoteCallback
            AppSettings.shared.voteTutorialComplete = true
            self.dismissOverlay()
            self.onComplete?()
        }
    }

    // MARK: - Overlay panel

    private func showOverlay() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false

        let overlay = VoteTutorialOverlayView(manager: self)
        let hosting = NSHostingView(rootView: overlay)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func dismissOverlay() {
        panel?.close()
        panel = nil
    }

    func tearDown() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        edgePillarManager?.stopListening()
        edgePillarManager?.allowedSide = nil
        edgePillarManager?.onVoteRecorded = originalVoteCallback
        breathGlowManager?.dismiss()
        dismissOverlay()
    }
}
