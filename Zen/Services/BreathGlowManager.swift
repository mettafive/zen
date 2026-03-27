import AppKit
import SwiftUI

@MainActor
final class BreathGlowManager {
    private var glowPanel: NSPanel?
    private var quotePanel: NSPanel?
    private var glowDismissTimer: Timer?
    private var pillController = QuotePillController()

    func breathe(withQuote: Bool = false) {
        dismissGlow()

        guard let screen = NSScreen.main else { return }
        let frame = screen.frame

        let gPanel = makePanel(frame: frame)
        let glowView = BreathGlowView()
        let gHosting = NSHostingView(rootView: glowView)
        gHosting.frame = NSRect(origin: .zero, size: frame.size)
        gPanel.contentView = gHosting
        gPanel.orderFrontRegardless()
        self.glowPanel = gPanel
        PanelHoverTracker.shared.register(gPanel)

        glowDismissTimer = Timer.scheduledTimer(withTimeInterval: 19, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismissGlow() }
        }

        if withQuote {
            showQuotePill()
        }
    }

    func showQuotePill(customText: String? = nil) {
        dismissQuote()

        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame

        let panelWidth: CGFloat = min(screenFrame.width - 100, 900)
        let panelHeight: CGFloat = 80

        let x = screenFrame.midX - panelWidth / 2
        let y = screenFrame.minY + 40

        let qPanel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        qPanel.isFloatingPanel = true
        qPanel.level = .screenSaver
        qPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        qPanel.isOpaque = false
        qPanel.backgroundColor = .clear
        qPanel.hasShadow = false
        qPanel.ignoresMouseEvents = true
        qPanel.hidesOnDeactivate = false

        let quote = customText ?? MoodStore.shared.nextQuote()
        pillController = QuotePillController()

        let pillView = QuotePillView(text: quote, controller: pillController)
        let hosting = NSHostingView(rootView: pillView)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: panelHeight))
        qPanel.contentView = hosting

        qPanel.orderFrontRegardless()
        self.quotePanel = qPanel
        PanelHoverTracker.shared.register(qPanel)

        pillController.show()
    }

    func onVoteCompleted() {
        pillController.startCountdown { [weak self] in
            Task { @MainActor in
                self?.dismissQuote()
            }
        }
    }

    private var restoreTimer: Timer?

    /// Dim glow to 30% when user is actively voting
    func dimGlow() {
        restoreTimer?.invalidate()
        restoreTimer = nil
        guard let panel = glowPanel else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.4
            panel.animator().alphaValue = 0.3
        }
    }

    /// Restore glow after 2 second delay
    func scheduleRestoreGlow() {
        restoreTimer?.invalidate()
        restoreTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, let panel = self.glowPanel else { return }
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.6
                    panel.animator().alphaValue = 1.0
                }
            }
        }
    }

    func dismiss() {
        restoreTimer?.invalidate()
        restoreTimer = nil
        dismissGlow()
        dismissQuote()
    }

    func dismissGlow() {
        glowDismissTimer?.invalidate()
        glowDismissTimer = nil
        if let p = glowPanel { PanelHoverTracker.shared.unregister(p) }
        glowPanel?.close()
        glowPanel = nil
    }

    func dismissQuote() {
        if let p = quotePanel { PanelHoverTracker.shared.unregister(p) }
        quotePanel?.close()
        quotePanel = nil
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating // below quote pill (.screenSaver)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        return panel
    }
}

// MARK: - Breath glow

struct BreathGlowView: View {
    @State private var glowOpacity: CGFloat = 0
    @State private var breathCount = 0

    private var glowColor: Color {
        AppSettings.shared.glowTheme == "orange"
            ? Color(red: 0.95, green: 0.63, blue: 0.21)
            : Color.white
    }

    var body: some View {
        Rectangle()
            .fill(Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 0)
                    .stroke(glowColor, lineWidth: 110)
                    .blur(radius: 42)
                    .opacity(AppSettings.shared.glowTheme == "orange" ? 0.35 : 0.4)
            )
            .clipped()
            .opacity(glowOpacity)
            .allowsHitTesting(false)
            .onAppear { breathIn() }
    }

    private func breathIn() {
        guard breathCount < 3 else { return }
        withAnimation(.easeInOut(duration: 3)) { glowOpacity = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { breathOut() }
    }

    private func breathOut() {
        withAnimation(.easeInOut(duration: 3)) { glowOpacity = 0 }
        breathCount += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { breathIn() }
    }
}
