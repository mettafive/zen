import AppKit
import SwiftUI

@MainActor
final class ToastManager {
    private var panel: NSPanel?
    private var dismissTimer: Timer?

    private var reminders: [String] { MoodStore.shared.activeMood.reminders }

    private var recentIndices: [Int] = []

    func showBodyReminder() {
        let index = nextReminderIndex()
        show(text: reminders[index], duration: 8)
    }

    /// Pick a random reminder, but don't repeat any of the last 4
    private func nextReminderIndex() -> Int {
        var available = Array(0..<reminders.count).filter { !recentIndices.contains($0) }
        if available.isEmpty {
            // Safety fallback — shouldn't happen with 25 reminders and 4 recent
            recentIndices.removeAll()
            available = Array(0..<reminders.count)
        }
        let index = available.randomElement()!
        recentIndices.append(index)
        if recentIndices.count > 4 {
            recentIndices.removeFirst()
        }
        return index
    }

    private func show(text: String, duration: TimeInterval) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let panelWidth: CGFloat = 400
        let panelHeight: CGFloat = 80

        let x = screen.frame.midX - panelWidth / 2
        let y = screen.frame.minY + 30

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

        let toast = BodyReminderView(text: text, duration: duration)
        let hosting = NSHostingView(rootView: toast)
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: panelWidth, height: panelHeight))
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.panel = panel
        PanelHoverTracker.shared.register(panel)

        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration + 1.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
    }

    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        if let p = panel { PanelHoverTracker.shared.unregister(p) }
        panel?.close()
        panel = nil
    }
}

struct BodyReminderView: View {
    let text: String
    let duration: TimeInterval

    @State private var isVisible = false
    @State private var pillScale: CGFloat = 0.1

    var body: some View {
        ZenPillView(
            isVisible: isVisible,
            pillScale: pillScale,
            shadowOpacity: 1.0,
            lineProgress: 0,
            lineVisible: false,
            showShimmer: false
        ) {
            Text(text)
                .font(ZenPillStyle.textFont)
                .foregroundStyle(ZenPillStyle.textColor)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isVisible = true
                    pillScale = 1.0
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + duration - 0.6) {
                withAnimation(.easeIn(duration: 0.6)) {
                    isVisible = false
                    pillScale = 0.6
                }
            }
        }
    }
}
