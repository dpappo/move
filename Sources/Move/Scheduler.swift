import AppKit
import CoreGraphics

/// Decides when the next reminder is due. Ticks quietly every few seconds.
@MainActor
final class Scheduler {
    private(set) var nextBreak = Date()
    private(set) var pausedUntil: Date?
    private(set) var isShowing = false

    var onDue: (() -> Void)?

    /// If you've been away from the keyboard this long, you've already had a break.
    private let awayThreshold: TimeInterval = 5 * 60
    private var timer: Timer?

    var interval: TimeInterval { TimeInterval(Settings.intervalMinutes * 60) }

    func start() {
        reset()
        let timer = Timer(timeInterval: 5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didWakeNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, !self.isShowing else { return }
                    self.reset()
                }
            }
        }
    }

    private func tick() {
        let now = Date()
        guard !isShowing else { return }

        if let until = pausedUntil {
            guard now >= until else { return }
            pausedUntil = nil
            reset()
        }
        if Settings.workHoursOnly && !WorkHours.contains(now) {
            reset()
            return
        }
        if Self.idleSeconds() >= awayThreshold {
            reset()
            return
        }
        if now >= nextBreak {
            isShowing = true
            onDue?()
        }
    }

    // MARK: Actions

    func showNow() {
        guard !isShowing else { return }
        isShowing = true
        onDue?()
    }

    func completeBreak() {
        Settings.recordBreak()
        isShowing = false
        reset()
    }

    func snooze(minutes: Int) {
        isShowing = false
        nextBreak = Date().addingTimeInterval(TimeInterval(minutes * 60))
    }

    func pause(hours: Double) {
        pausedUntil = Date().addingTimeInterval(hours * 3600)
    }

    func pauseUntilTomorrow() {
        let cal = Calendar.current
        let tomorrow = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date())!)
        pausedUntil = tomorrow
    }

    func resume() {
        pausedUntil = nil
        reset()
    }

    func reset() {
        nextBreak = Date().addingTimeInterval(interval)
    }

    // MARK: Status

    var isPaused: Bool { pausedUntil.map { $0 > Date() } ?? false }

    var statusText: String {
        let now = Date()
        if isShowing { return "Time to move" }
        if let until = pausedUntil, until > now {
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        }
        if Settings.workHoursOnly && !WorkHours.contains(now) { return "Resting — outside work hours" }
        let minutes = max(1, Int(ceil(nextBreak.timeIntervalSince(now) / 60)))
        return "Next break in \(minutes) min"
    }

    private static func idleSeconds() -> TimeInterval {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState,
                                                eventType: CGEventType(rawValue: ~0)!)
    }
}
