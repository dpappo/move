import AppKit
import EventKit

/// Knows when you're in a meeting, from the events in the Mac's Calendar app. Google Calendar shows up
/// there once your Google account is added in System Settings → Internet Accounts, so no sign-in or
/// network access is needed here.
@MainActor
enum Meetings {
    private static var store = EKEventStore()

    static var hasAccess: Bool { EKEventStore.authorizationStatus(for: .event) == .fullAccess }

    /// Whether reminders currently wait for meetings to end.
    static var isOn: Bool { Settings.avoidMeetings && hasAccess }

    /// The meeting you're in right now: when the latest of them began and when the last one ends.
    static func current(at now: Date = Date()) -> (began: Date, ends: Date)? {
        guard isOn else { return nil }
        let predicate = store.predicateForEvents(withStart: now.addingTimeInterval(-1), end: now.addingTimeInterval(1),
                                                 calendars: nil)
        let events = store.events(matching: predicate).filter { $0.startDate <= now && $0.endDate > now && isMeeting($0) }
        guard let began = events.map(\.startDate).max(), let ends = events.map(\.endDate).max() else { return nil }
        return (began, ends)
    }

    /// An event with more than one person invited. Skips all-day events, ones you declined, and read-only
    /// calendars such as a teammate's calendar you can only view.
    private static func isMeeting(_ event: EKEvent) -> Bool {
        guard !event.isAllDay,
              event.status != .canceled,
              event.calendar.allowsContentModifications else { return false }
        // Some calendars list the organizer among the attendees and some don't, so count unique people.
        let people = Set((event.attendees ?? []).map(\.url) + [event.organizer?.url].compactMap { $0 })
        guard people.count > 1 else { return false }
        let me = event.attendees?.first(where: \.isCurrentUser)
        return me?.participantStatus != .declined
    }

    /// Asks for calendar access the first time, or explains how to turn it back on if it was denied.
    static func requestAccess(then done: @escaping @MainActor (Bool) -> Void) {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            done(true)
        case .notDetermined:
            NSApp.activate(ignoringOtherApps: true)
            store.requestFullAccessToEvents { granted, _ in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        // A store made before access was granted can keep returning nothing.
                        if granted { store = EKEventStore() }
                        done(granted)
                    }
                }
            }
        default:
            showDeniedAlert()
            done(false)
        }
    }

    private static func showDeniedAlert() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move can't see your calendar"
        alert.informativeText = "To hold reminders during meetings, allow Move full access to Calendars in "
            + "System Settings → Privacy & Security → Calendars."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }
}
