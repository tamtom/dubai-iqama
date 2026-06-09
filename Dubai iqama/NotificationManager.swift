import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private var hasNotifiedForCurrentIqama = false
    private var lastNotifiedPrayer: Prayer?

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
        guard case .waitingForIqama(let prayer, _) = snapshot.phase else {
            // Reset when not in iqama phase
            hasNotifiedForCurrentIqama = false
            lastNotifiedPrayer = nil
            return
        }

        // Check if we already notified for this prayer's iqama
        if hasNotifiedForCurrentIqama && lastNotifiedPrayer == prayer {
            return
        }

        // Check if time remaining is 10 minutes or less (but more than 9 minutes to avoid repeat)
        let tenMinutes: TimeInterval = 10 * 60
        let nineMinutes: TimeInterval = 9 * 60

        if snapshot.timeRemaining <= tenMinutes && snapshot.timeRemaining > nineMinutes {
            sendIqamaNotification(for: prayer, minutesRemaining: 10)
            hasNotifiedForCurrentIqama = true
            lastNotifiedPrayer = prayer
        }
    }

    private func sendIqamaNotification(for prayer: Prayer, minutesRemaining: Int) {
        let content = UNMutableNotificationContent()
        content.title = "\(prayer.displayName) Iqama"
        content.body = "\(minutesRemaining) minutes until \(prayer.displayName) Iqama"
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
