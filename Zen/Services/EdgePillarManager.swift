import AppKit
import SwiftUI

@MainActor
final class EdgePillarManager {
    private var leftPanel: NSPanel?
    private var rightPanel: NSPanel?
    private var mouseMonitor: Any?
    private var localMonitor: Any?
    private var physicsTimer: Timer?

    // State
    private(set) var isListening = false
    private var isAtLeft = false
    private var isAtRight = false

    // Independent physics per side
    private var leftFill: CGFloat = 0
    private var leftVelocity: CGFloat = 0
    private var leftPrevFill: CGFloat = 0
    private var leftLingerTime: CGFloat = 0 // time since mouse left

    private var rightFill: CGFloat = 0
    private var rightVelocity: CGFloat = 0
    private var rightPrevFill: CGFloat = 0
    private var rightLingerTime: CGFloat = 0

    private let lingerDuration: CGFloat = 0.15 // 150ms hang before gravity

    // Deferred completion (can't stop mid-tick due to inout refs)
    private var pendingCompletion: EdgeSide? = nil

    // Physics constants
    private let gravity: CGFloat = 1.89
    private let completionGravityMultiplier: CGFloat = 1.25
    private var voteCompleted = false
    private let fillRate: CGFloat = 0.5 // 2s to full
    private let tickInterval: TimeInterval = 1.0 / 60.0

    // Config
    private let edgeThreshold: CGFloat = 15
    private let pillarWidth: CGFloat = 23
    var onVoteRecorded: ((Bool) -> Void)?
    var onEdgeEngaged: (() -> Void)?
    var onEdgeDisengaged: (() -> Void)?
    private var wasEngaged = false

    enum EdgeSide {
        case left, right
    }

    // MARK: - Listening

    func startListening() {
        guard !isListening else { return }
        isListening = true
        leftFill = 0; leftVelocity = 0; leftLingerTime = 0
        rightFill = 0; rightVelocity = 0; rightLingerTime = 0
        voteCompleted = false
        isAtLeft = false; isAtRight = false

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            Task { @MainActor in self?.handleMousePosition() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            Task { @MainActor in self?.handleMousePosition() }
            return event
        }

        startPhysicsLoop()
    }

    func stopListening() {
        isListening = false
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        localMonitor = nil
        physicsTimer?.invalidate()
        physicsTimer = nil
        dismissPanel(&leftPanel)
        dismissPanel(&rightPanel)
    }

    // MARK: - Mouse tracking

    private func handleMousePosition() {
        guard isListening else { return }

        let mouseX = NSEvent.mouseLocation.x
        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let atLeft = mouseX <= frame.minX + edgeThreshold
        let atRight = mouseX >= frame.maxX - edgeThreshold

        // Left edge
        if atLeft && !isAtLeft {
            isAtLeft = true
            leftVelocity = 0
            leftLingerTime = 0
            ensurePanelVisible(edge: .left)
            HapticService.playAlignment()
        } else if !atLeft && isAtLeft {
            isAtLeft = false
            leftLingerTime = 0 // start linger countdown
        }

        if atRight && !isAtRight {
            isAtRight = true
            rightVelocity = 0
            rightLingerTime = 0
            ensurePanelVisible(edge: .right)
            HapticService.playAlignment()
        } else if !atRight && isAtRight {
            isAtRight = false
            rightLingerTime = 0
        }

        // Notify glow manager of engagement state
        let isEngaged = isAtLeft || isAtRight
        if isEngaged && !wasEngaged {
            wasEngaged = true
            onEdgeEngaged?()
        } else if !isEngaged && wasEngaged {
            wasEngaged = false
            onEdgeDisengaged?()
        }
    }

    // MARK: - Physics loop (60fps)

    private func startPhysicsLoop() {
        physicsTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.physicsTick() }
        }
    }

    private func physicsTick() {
        guard isListening else { return }
        let dt = CGFloat(tickInterval)
        pendingCompletion = nil

        // Left side physics
        tickSide(
            isAtEdge: isAtLeft,
            fill: &leftFill,
            velocity: &leftVelocity,
            prevFill: &leftPrevFill,
            lingerTime: &leftLingerTime,
            edge: .left,
            panel: &leftPanel,
            dt: dt
        )

        // Right side physics (only if left didn't complete)
        if pendingCompletion == nil {
            tickSide(
                isAtEdge: isAtRight,
                fill: &rightFill,
                velocity: &rightVelocity,
                prevFill: &rightPrevFill,
                lingerTime: &rightLingerTime,
                edge: .right,
                panel: &rightPanel,
                dt: dt
            )
        }

        // Handle completion outside of inout context
        if let edge = pendingCompletion {
            completeFill(edge: edge)
        }

        // After vote recorded, stop physics once all water has drained
        if mouseMonitor == nil && leftFill <= 0 && rightFill <= 0 && leftPanel == nil && rightPanel == nil {
            physicsTimer?.invalidate()
            physicsTimer = nil
            isListening = false
        }
    }

    private func tickSide(
        isAtEdge: Bool,
        fill: inout CGFloat,
        velocity: inout CGFloat,
        prevFill: inout CGFloat,
        lingerTime: inout CGFloat,
        edge: EdgeSide,
        panel: inout NSPanel?,
        dt: CGFloat
    ) {
        if isAtEdge {
            // Filling — slow start, fast finish
            lingerTime = 0 // reset linger so it doesn't carry over
            prevFill = fill
            let rate = fill < 0.15 ? fillRate * 0.8 : fill >= 0.8 ? fillRate * 1.8 : fillRate
            fill += rate * dt
            velocity = 0

            HapticService.handleBreathProgress(fill, previousProgress: prevFill)

            if fill >= 1.0 {
                fill = 1.0
                pendingCompletion = edge
                return
            }

            updateVisual(edge: edge, fill: fill, opacity: 1, panel: &panel)

        } else if fill > 0 {
            // Linger — water hangs for a moment before falling
            lingerTime += dt
            if lingerTime < lingerDuration {
                // Just hang, don't fall yet
                updateVisual(edge: edge, fill: fill, opacity: 1, panel: &panel)
                return
            }

            // Falling with gravity (faster after vote)
            let g = voteCompleted ? gravity * completionGravityMultiplier : gravity
            velocity += g * dt
            fill -= velocity * dt

            if fill <= 0 {
                fill = 0
                velocity = 0
                dismissPanel(&panel)
                return
            }

            let opacity: CGFloat = fill < 0.15 ? fill / 0.15 : 1.0
            updateVisual(edge: edge, fill: fill, opacity: opacity, panel: &panel)
        }
    }

    // MARK: - Completion

    private func completeFill(edge: EdgeSide) {
        let wasPresent = edge == .left

        HapticService.playLevelChange()
        SoundService.shared.playSelectionSound()

        // Stop mouse monitors — no more input
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        localMonitor = nil
        isAtLeft = false
        isAtRight = false

        // Boost gravity for faster fall
        voteCompleted = true

        // Record vote immediately — physics loop keeps running to let the water fall
        onVoteRecorded?(wasPresent)

        // Dismiss the other side
        if edge == .left {
            dismissPanel(&rightPanel)
            rightFill = 0; rightVelocity = 0
        } else {
            dismissPanel(&leftPanel)
            leftFill = 0; leftVelocity = 0
        }

        // Skip linger on the winning side — fall immediately
        if edge == .left {
            leftLingerTime = lingerDuration
        } else {
            rightLingerTime = lingerDuration
        }

        // The winning side: just release it — gravity does the rest
        // Physics loop is still running, isAtEdge is false, so it falls naturally
        // Once it hits 0, dismissPanel is called by tickSide and we clean up
    }

    // MARK: - Panel management

    private func ensurePanelVisible(edge: EdgeSide) {
        switch edge {
        case .left:
            if leftPanel == nil { createPanel(edge: .left, panel: &leftPanel) }
        case .right:
            if rightPanel == nil { createPanel(edge: .right, panel: &rightPanel) }
        }
    }

    private func createPanel(edge: EdgeSide, panel: inout NSPanel?) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x: CGFloat = edge == .left ? screenFrame.minX : screenFrame.maxX - pillarWidth
        let panelFrame = NSRect(x: x, y: screenFrame.minY, width: pillarWidth, height: screenFrame.height)

        let p = NSPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel = true
        p.level = .screenSaver
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.hidesOnDeactivate = false

        p.alphaValue = 0
        p.orderFrontRegardless()
        panel = p

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            p.animator().alphaValue = 1
        }
    }

    private func updateVisual(edge: EdgeSide, fill: CGFloat, opacity: CGFloat, panel: inout NSPanel?) {
        guard let p = panel else {
            createPanel(edge: edge, panel: &panel)
            return
        }

        let pillarView = PillarFillView(edge: edge, fillProgress: fill)
        let hosting = NSHostingView(rootView: pillarView)
        hosting.frame = p.contentView?.bounds ?? .zero
        p.contentView = hosting
        p.alphaValue = opacity
    }

    private func dismissPanel(_ panel: inout NSPanel?) {
        panel?.close()
        panel = nil
    }
}

// MARK: - Visual

struct PillarFillView: View {
    let edge: EdgePillarManager.EdgeSide
    let fillProgress: CGFloat

    @State private var wavePhase: CGFloat = 0
    @State private var sloshOffset: CGFloat = 0

    private var color: Color {
        edge == .left
            ? Color(red: 0.95, green: 0.6, blue: 0.2)  // orange — dhamma
            : Color(red: 0.15, green: 0.15, blue: 0.15) // black — mara
    }

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let waterTop = h * (1 - fillProgress)

            ZStack(alignment: .bottom) {
                // Background tint
                Rectangle()
                    .fill(color.opacity(0.06))

                // Layer 1 — 1.0 speed (lightest), sloshes horizontally
                Rectangle()
                    .fill(color.opacity(0.15 + Double(fillProgress) * 0.1))
                    .frame(height: h * fillProgress)
                    .offset(x: sloshOffset * fillProgress)

                // Layer 2 — 0.99 speed
                Rectangle()
                    .fill(color.opacity(0.2 + Double(fillProgress) * 0.15))
                    .frame(height: h * fillProgress * 0.99)

                // Layer 3 — 0.98 speed (darkest)
                Rectangle()
                    .fill(color.opacity(0.25 + Double(fillProgress) * 0.2))
                    .frame(height: h * fillProgress * 0.98)

                // Wave surface — connected to fastest layer, 30% less opacity
                if fillProgress > 0.01 && fillProgress < 0.99 {
                    Path { path in
                        let w = geo.size.width
                        let steps = max(1, Int(w))
                        for i in 0...steps {
                            let x = CGFloat(i)
                            let wave = sin(x / w * .pi * 3 + wavePhase) * 2.5
                            let pt = CGPoint(x: x, y: waterTop + wave)
                            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
                        }
                    }
                    .stroke(color.opacity(0.35), lineWidth: 1.5)
                }
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                wavePhase = .pi * 2
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                sloshOffset = 3
            }
        }
    }
}

