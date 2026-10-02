import AppKit
import ServiceManagement

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let scheduler = Scheduler()
    private let session = BreakSession()
    private lazy var panel = ReminderPanelController(session: session)
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        scheduler.onDue = { [weak self] in
            self?.panel.show()
            self?.updateIcon()
        }
        session.onDone = { [weak self] in
            self?.scheduler.completeBreak()
            self?.panel.hide()
            self?.updateIcon()
        }
        session.onSnooze = { [weak self] in
            self?.scheduler.snooze(minutes: 10)
            self?.panel.hide()
            self?.updateIcon()
        }
        scheduler.start()
        enableLoginOnFirstRun()

        if CommandLine.arguments.contains("--now") { scheduler.showNow() }
    }

    /// Opens at login by default; turning it off in the menu is remembered.
    private func enableLoginOnFirstRun() {
        let key = "didSetUpLoginItem"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
            NSLog("Move: open at login enabled")
        } catch {
            NSLog("Move: could not enable open at login: \(error.localizedDescription)")
        }
    }

    private func updateIcon() {
        let name = scheduler.isPaused ? "figure.stand" : "figure.walk"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Move")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = scheduler.isPaused
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let status = NSMenuItem(title: scheduler.statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)

        let breaks = Settings.breaksToday
        if breaks > 0 {
            let today = NSMenuItem(title: "\(breaks) \(breaks == 1 ? "break" : "breaks") today", action: nil, keyEquivalent: "")
            today.isEnabled = false
            menu.addItem(today)
        }

        menu.addItem(.separator())
        menu.addItem(item("Move Now", #selector(moveNow), key: "m"))

        if scheduler.isPaused {
            menu.addItem(item("Resume", #selector(resume)))
        } else {
            let pause = NSMenuItem(title: "Pause", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.addItem(item("For 30 Minutes", #selector(pause(_:)), tag: 30))
            sub.addItem(item("For 1 Hour", #selector(pause(_:)), tag: 60))
            sub.addItem(item("For 2 Hours", #selector(pause(_:)), tag: 120))
            sub.addItem(item("Until Tomorrow", #selector(pauseUntilTomorrow)))
            pause.submenu = sub
            menu.addItem(pause)
        }

        menu.addItem(.separator())

        let every = NSMenuItem(title: "Remind Every", action: nil, keyEquivalent: "")
        let intervals = NSMenu()
        for minutes in [30, 45, 60] {
            let i = item("\(minutes) Minutes", #selector(setInterval(_:)), tag: minutes)
            i.state = Settings.intervalMinutes == minutes ? .on : .off
            intervals.addItem(i)
        }
        every.submenu = intervals
        menu.addItem(every)

        let hours = item("Only During Work Hours", #selector(toggleWorkHours))
        hours.state = Settings.workHoursOnly ? .on : .off
        hours.toolTip = "Monday–Friday, \(WorkHours.startHour):00–\(WorkHours.endHour):00"
        menu.addItem(hours)

        let chimes = item("Soft Chimes in Guide", #selector(toggleChimes))
        chimes.state = Settings.chimes ? .on : .off
        menu.addItem(chimes)

        let login = item("Open at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        menu.addItem(item("Quit Move", #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "", tag: Int = 0) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        item.tag = tag
        return item
    }

    @objc private func moveNow() { scheduler.showNow() }

    @objc private func pause(_ sender: NSMenuItem) {
        scheduler.pause(hours: Double(sender.tag) / 60)
        updateIcon()
    }

    @objc private func pauseUntilTomorrow() {
        scheduler.pauseUntilTomorrow()
        updateIcon()
    }

    @objc private func resume() {
        scheduler.resume()
        updateIcon()
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        Settings.intervalMinutes = sender.tag
        if !scheduler.isShowing { scheduler.reset() }
    }

    @objc private func toggleWorkHours() {
        Settings.workHoursOnly.toggle()
        if !scheduler.isShowing { scheduler.reset() }
    }

    @objc private func toggleChimes() { Settings.chimes.toggle() }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled { try service.unregister() } else { try service.register() }
        } catch {
            NSSound.beep()
            NSLog("Move: login item change failed: \(error.localizedDescription)")
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
