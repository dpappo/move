import AppKit
import SwiftUI

/// A floating, non-activating card in the top-right corner. It never steals focus from what you're doing.
@MainActor
final class ReminderPanelController {
    static let cardSize = NSSize(width: 340, height: 388)
    private let margin: CGFloat = 14
    private let slide: CGFloat = 18

    private let session: BreakSession
    private var panel: NSPanel?

    init(session: BreakSession) {
        self.session = session
    }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        session.prepare()

        let target = targetFrame()
        panel.setFrame(target.offsetBy(dx: slide, dy: 0), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(target, display: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { panel.invalidateShadow() }
    }

    func hide() {
        guard let panel, panel.isVisible else { return }
        let frame = panel.frame
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(frame.offsetBy(dx: slide, dy: 0), display: true)
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }

    private func targetFrame() -> NSRect {
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let visible = screen.visibleFrame
        let size = Self.cardSize
        return NSRect(x: visible.maxX - size.width - margin,
                      y: visible.maxY - size.height - margin,
                      width: size.width,
                      height: size.height)
    }

    private func makePanel() -> NSPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: Self.cardSize),
                                  styleMask: [.borderless, .nonactivatingPanel],
                                  backing: .buffered,
                                  defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .none

        let host = FirstMouseHostingView(rootView: ReminderView(session: session))
        host.frame = NSRect(origin: .zero, size: Self.cardSize)
        host.sizingOptions = []
        panel.contentView = host
        return panel
    }
}

private final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Buttons respond on the very first click, even though the card never activates the app.
private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
