import UIKit
import UserNotifications

// MARK: - PushNotifications
// Requests notification authorization and triggers APNs registration. The
// resulting device token is delivered to AppDelegate, which forwards it to the
// backend `/v1/notifications/register` endpoint.

enum PushNotifications {

    /// Ask for authorization (if not yet decided) and register with APNs when granted.
    /// Safe to call on every launch — the system only prompts once.
    static func requestAuthorizationAndRegister() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                    if let error { CrashReporter.record(error) }
                    guard granted else { return }
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            case .authorized, .provisional, .ephemeral:
                // Already authorized — refresh the token (it can rotate).
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    /// Open the system settings page so users can re-enable notifications they declined.
    static func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
