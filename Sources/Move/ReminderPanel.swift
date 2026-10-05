import AppKit
import Combine
import SwiftUI

/// A floating, non-activating card in the top-right corner. It never steals focus from what you're doing.
/// When you ask to be guided, it glides to the middle of the screen and grows to show each movement.
@MainActor
final class ReminderPanelController {
    static let cardSize = NSSize(width: 340, height: 420)
    static let guideSize = NSSize(width: 400, height: 500)

    static func size(for phase: BreakSession.Phase) -> NSSize {
        phase == .prompt ? cardSize : guideSize
    }

    private let margin: CGFloat = 14
    private let slide: CGFloat = 18

    private let session: BreakSession
    private var panel: NSPanel?
    private var phaseObserver: AnyCancellable?

    init(session: BreakSession) {
        self.session = session
        phaseObserver = session.$phase.removeDuplicates().sink { [weak self] phase in
            MainActor.assumeIsolated {
                if phase == .guiding { self?.moveToCenter() }
            }
        }
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
        // Slide back out toward the corner, or settle down and away from the middle of the screen.
        let away = frame.size == Self.cardSize ? frame.offsetBy(dx: slide, dy: 0) : frame.offsetBy(dx: 0, dy: -slide / 2)
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.3
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(away, display: true)
        }, completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        })
    }

    private func moveToCenter() {
        guard let panel, panel.isVisible, let screen = panel.screen ?? NSScreen.main else { return }
        let size = Self.guideSize
        let full = screen.frame, visible = screen.visibleFrame
        let x = min(max(full.midX - size.width / 2, visible.minX), visible.maxX - size.width)
        let y = min(max(full.midY - size.height / 2, visible.minY), visible.maxY - size.height)
        let target = NSRect(x: x.rounded(), y: y.rounded(), width: size.width, height: size.height)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.6
            ctx.timingFunction = CAMediaTimingFunction(controlPoints: 0.3, 0.8, 0.25, 1)
            panel.animator().setFrame(target, display: true)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { panel.invalidateShadow() }
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
        host.autoresizingMask = [.width, .height]

        // Clip everything the window draws to the card's rounded shape. Without this, the system paints
        // a square-cornered backdrop behind the glass once the panel becomes key (e.g. after a click).
        let clip = NSView(frame: host.frame)
        clip.wantsLayer = true
        clip.layer?.cornerRadius = ReminderView.cornerRadius
        clip.layer?.cornerCurve = .continuous
        clip.layer?.masksToBounds = true
        clip.addSubview(host)
        panel.contentView = clip
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
