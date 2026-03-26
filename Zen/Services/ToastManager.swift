import AppKit
import SwiftUI

@MainActor
final class ToastManager {
    private var panel: NSPanel?
    private var dismissTimer: Timer?

    private var reminders: [String] { MoodStore.shared.activeMood.reminders }

    private var usedIndices: [Int] = []

    func showBodyReminder() {
        let index = nextReminderIndex()
        show(text: reminders[index], duration: 8)
    }

    /// Pick a random reminder, cycling through all before repeating any
    private func nextReminderIndex() -> Int {
        usedIndices = usedIndices.filter { $0 < reminders.count }
        var available = Array(0..<reminders.count).filter { !usedIndices.contains($0) }
        if available.isEmpty {
            usedIndices.removeAll()
            available = Array(0..<reminders.count)
        }
        let index = available.randomElement()!
        usedIndices.append(index)
        return index
    }

    private func show(text: String, duration: TimeInterval) {
        dismiss()

        guard let screen = NSScreen.main else { return }

        let maxPanelWidth: CGFloat = 600
        let panelHeight: CGFloat = 80

        let x = screen.frame.midX - maxPanelWidth / 2
        let y = screen.frame.minY + 30

        let panel = NSPanel(
            contentRect: NSRect(x: x, y: y, width: maxPanelWidth, height: panelHeight),
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
        hosting.frame = NSRect(origin: .zero, size: NSSize(width: maxPanelWidth, height: panelHeight))
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
                .lineLimit(2)
                .minimumScaleFactor(0.9)
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
