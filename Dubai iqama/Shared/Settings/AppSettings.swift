import Foundation

// Storage keys and defaults for the small set of user-tunable preferences.
// Views read these via @AppStorage(AppSettings.Keys.X); non-view code reads
// UserDefaults directly via AppSettings.notificationLeadMinutes / .notificationsEnabled.
enum AppSettings {
    enum Keys {
        static let notificationLeadMinutes = "notificationLeadMinutes"
        static let notificationsEnabled = "notificationsEnabled"
    }

    enum Defaults {
        static let notificationLeadMinutes = 10
        static let notificationsEnabled = true
    }

    // Friendly choices we render in the settings picker.
    static let leadMinuteChoices: [Int] = [2, 5, 10, 15, 20, 30]

    static var notificationLeadMinutes: Int {
        let v = UserDefaults.standard.object(forKey: Keys.notificationLeadMinutes) as? Int
        return v ?? Defaults.notificationLeadMinutes
    }

    static var notificationsEnabled: Bool {
        let v = UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool
        return v ?? Defaults.notificationsEnabled
    }
}
