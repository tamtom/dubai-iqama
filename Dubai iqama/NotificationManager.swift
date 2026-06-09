import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var hasNotifiedForCurrentIqama = false
    private var lastNotifiedPrayer: Prayer?
    private var lastNotifiedLead: Int?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Send Notification

    func checkAndNotifyForIqama(snapshot: CountdownSnapshot) {
        guard AppSettings.notificationsEnabled, AppSettings.notificationLeadMinutes > 0 else {
            hasNotifiedForCurrentIqama = false
            lastNotifiedPrayer = nil
            return
        }
        let lead = AppSettings.notificationLeadMinutes

        guard case .waitingForIqama(let prayer, _) = snapshot.phase else {
            // Reset when not in iqama phase
            hasNotifiedForCurrentIqama = false
            lastNotifiedPrayer = nil
            return
        }

        // Already fired for this prayer at the current lead setting.
        if hasNotifiedForCurrentIqama && lastNotifiedPrayer == prayer && lastNotifiedLead == lead {
            return
        }

        // Fire when remaining time enters the [lead-1m, lead] window. Using a 1-min
        // band avoids re-firing as the countdown ticks across the threshold.
        let upper: TimeInterval = TimeInterval(lead) * 60
        let lower: TimeInterval = TimeInterval(max(0, lead - 1)) * 60

        if snapshot.timeRemaining <= upper && snapshot.timeRemaining > lower {
            sendIqamaNotification(for: prayer, minutesRemaining: lead)
            hasNotifiedForCurrentIqama = true
            lastNotifiedPrayer = prayer
            lastNotifiedLead = lead
        }
    }

    private func sendIqamaNotification(for prayer: Prayer, minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(prayer.displayName) Iqama"
        content.body = "\(minutesRemaining) minute\(minutesRemaining == 1 ? "" : "s") until \(prayer.displayName) Iqama"
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        let request = UNNotificationRequest(
            identifier: "iqama-\(prayer.rawValue)-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // Deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to send notification: \(error)")
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
