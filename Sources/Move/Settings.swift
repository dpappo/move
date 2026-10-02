import Foundation

enum Settings {
    private static let defaults = UserDefaults.standard

    static var intervalMinutes: Int {
        get { let v = defaults.integer(forKey: "intervalMinutes"); return v == 0 ? 30 : v }
        set { defaults.set(newValue, forKey: "intervalMinutes") }
    }

    static var workHoursOnly: Bool {
        get { defaults.object(forKey: "workHoursOnly") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "workHoursOnly") }
    }

    static var chimes: Bool {
        get { defaults.object(forKey: "chimes") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "chimes") }
    }

    static var breaksToday: Int { defaults.integer(forKey: todayKey) }

    static func recordBreak() {
        defaults.set(breaksToday + 1, forKey: todayKey)
    }

    private static var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "breaks-" + f.string(from: Date())
    }
}

/// Monday–Friday, 9:00–18:00 local time.
enum WorkHours {
    static let startHour = 9
    static let endHour = 18

    static func contains(_ date: Date) -> Bool {
        let cal = Calendar.current
        guard (2...6).contains(cal.component(.weekday, from: date)) else { return false }
        let hour = cal.component(.hour, from: date)
        return hour >= startHour && hour < endHour
    }
}
