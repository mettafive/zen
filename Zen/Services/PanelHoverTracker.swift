import AppKit

/// Dims any registered NSPanel to 30% opacity when the mouse hovers over it.
/// Panels keep `ignoresMouseEvents = true` — detection uses global mouse position.
@MainActor
final class PanelHoverTracker {
    static let shared = PanelHoverTracker()

    private var panels: [ObjectIdentifier: NSPanel] = [:]
    private var hoveredPanels: Set<ObjectIdentifier> = []
    private var mouseMonitor: Any?
    private var localMonitor: Any?

    private init() {}

    func register(_ panel: NSPanel) {
        let id = ObjectIdentifier(panel)
        panels[id] = panel
        startMonitoringIfNeeded()
    }

    func unregister(_ panel: NSPanel) {
        let id = ObjectIdentifier(panel)
        panels.removeValue(forKey: id)
        hoveredPanels.remove(id)
        if panels.isEmpty { stopMonitoring() }
    }

    private func startMonitoringIfNeeded() {
        guard mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in self?.check() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            Task { @MainActor in self?.check() }
            return event
        }
    }

    private func stopMonitoring() {
        if let m = mouseMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
        mouseMonitor = nil
        localMonitor = nil
    }

    private func check() {
        let mouse = NSEvent.mouseLocation
        for (id, panel) in panels {
            let inside = panel.frame.contains(mouse)
            let wasInside = hoveredPanels.contains(id)

            if inside && !wasInside {
                hoveredPanels.insert(id)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    panel.animator().alphaValue = 0.3
                }
            } else if !inside && wasInside {
                hoveredPanels.remove(id)
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
                    panel.animator().alphaValue = 1.0
                }
            }
        }
    }
}
