import AppKit
import SwiftUI

@MainActor
final class TopPeekManager {
    private var mouseMonitor: Any?
    private var localMonitor: Any?
    private var isListening = false
    private var isAtTop = false
    private var holdProgress: CGFloat = 0
    private var holdTimer: Timer?
    private var peekPanel: NSPanel?
    private var lineTimer: Timer?
    private var peekController = PeekPillController()

    private let edgeThreshold: CGFloat = 8
    private let holdDuration: TimeInterval = 2.0 // 33% shorter (was 3.0)
    private let tickInterval: TimeInterval = 1.0 / 60.0

    var getTimeRemaining: (() -> TimeInterval)?

    func startListening() {
        guard !isListening else { return }
        isListening = true
        isAtTop = false
        holdProgress = 0

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.handleMousePosition() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in self?.handleMousePosition() }
            return event
        }
    }

    func stopListening() {
        isListening = false
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        localMonitor = nil
        cancelHold()
        dismissPeek()
    }

    private func handleMousePosition() {
        guard isListening else { return }

        let mouseY = NSEvent.mouseLocation.y
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let atTop = mouseY >= frame.maxY - edgeThreshold

        if atTop && !isAtTop {
            isAtTop = true
            startHold()
        } else if !atTop && isAtTop {
            isAtTop = false
            cancelHold()
        }
    }

    private let deadZone: TimeInterval = 0.4
    private var deadZoneElapsed: TimeInterval = 0

    private func startHold() {
        holdProgress = 0
        deadZoneElapsed = 0
        var prevProgress: CGFloat = 0

        holdTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isAtTop else { return }

                // Wait through dead zone before starting haptics
                self.deadZoneElapsed += self.tickInterval
                guard self.deadZoneElapsed >= self.deadZone else { return }

                prevProgress = self.holdProgress
                self.holdProgress += CGFloat(self.tickInterval / self.holdDuration)

                HapticService.handleBreathProgress(self.holdProgress, previousProgress: prevProgress)

                if self.holdProgress >= 1.0 {
                    self.holdProgress = 1.0
                    self.completeHold()
                }
            }
        }
    }

    private func cancelHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        holdProgress = 0
    }

    private func completeHold() {
        holdTimer?.invalidate()
        holdTimer = nil
        HapticService.playLevelChange()
        showPeek()
    }

    // MARK: - Peek pill (reuses quote pill animation pattern)

    private func showPeek() {
        dismissPeek()

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let timeRemaining = getTimeRemaining?() ?? 0

        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 80
        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + 40

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
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

        peekController = PeekPillController()

        let timeString = timeRemaining.minutesAndSeconds
        let peekView = PeekPillView(timeString: timeString, controller: peekController)
        let hosting = NSHostingView(rootView: peekView)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: panelHeight))
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.peekPanel = panel
        PanelHoverTracker.shared.register(panel)

        // Start the entrance + line animation sequence
        peekController.show {
            // After full sequence completes, dismiss
            Task { @MainActor in
                self.dismissPeek()
            }
        }
    }

    private func dismissPeek() {
        lineTimer?.invalidate()
        lineTimer = nil
        if let p = peekPanel { PanelHoverTracker.shared.unregister(p) }
        peekPanel?.close()
        peekPanel = nil
    }
}

// MARK: - Peek pill controller (same pattern as QuotePillController)

@MainActor
class PeekPillController: ObservableObject {
    @Published var isVisible = false
    @Published var isExpanded = false
    @Published var pillScale: CGFloat = 1.0
    @Published var showText = false
    @Published var lineProgress: CGFloat = 0
    @Published var lineVisible = false
    @Published var lineExpanding = true

    private var lineTimer: Timer?

    func show(onComplete: @escaping () -> Void) {
        isExpanded = true
        pillScale = 0.1
        isVisible = false

        // Scale up + fade in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                self.pillScale = 1.0
                self.isVisible = true
            }
        }

        // Text fades in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.35)) {
                self.showText = true
            }
            self.lineVisible = true
            // Line expands from center over 3 seconds
            self.lineExpanding = true
            self.startLineAnimation(from: 0, to: 1, duration: 3.0) {
                // Line contracts back over 3 seconds
                self.lineExpanding = false
                self.startLineAnimation(from: 1, to: 0, duration: 3.0) {
                    // Close
                    withAnimation(.easeIn(duration: 0.3)) {
                        self.showText = false
                    }
                    self.lineVisible = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        withAnimation(.easeInOut(duration: 0.35)) {
                            self.isVisible = false
                            self.pillScale = 0.6
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            onComplete()
                        }
                    }
                }
            }
        }
    }

    private func startLineAnimation(from: CGFloat, to: CGFloat, duration: TimeInterval, onDone: @escaping () -> Void) {
        lineTimer?.invalidate()
        lineProgress = from
        let tick: TimeInterval = 1.0 / 30.0
        let step = CGFloat(tick / duration) * (to > from ? 1 : -1)

        lineTimer = Timer.scheduledTimer(withTimeInterval: tick, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.lineProgress += step
                if (step > 0 && self.lineProgress >= to) || (step < 0 && self.lineProgress <= to) {
                    self.lineProgress = to
                    self.lineTimer?.invalidate()
                    self.lineTimer = nil
                    onDone()
                }
            }
        }
    }
}

// MARK: - Peek pill view

struct PeekPillView: View {
    let timeString: String
    @ObservedObject var controller: PeekPillController

    var body: some View {
        ZenPillView(
            isVisible: controller.isVisible,
            pillScale: controller.pillScale,
            shadowOpacity: 1.0,
            lineProgress: controller.lineProgress,
            lineVisible: controller.lineVisible,
            showShimmer: false
        ) {
            if controller.showText {
                Text("time until next bell: \(timeString)")
                    .font(ZenPillStyle.textFont)
                    .foregroundStyle(ZenPillStyle.textColor)
                    .transition(.opacity)
            }
        }
        .frame(width: 360)
    }
}
