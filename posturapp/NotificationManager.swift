import Combine
import UserNotifications

final class NotificationManager: ObservableObject {

    @Published var authorizationGranted = false

    private let center = UNUserNotificationCenter.current()
    private let alertIdentifier = "posture.bad.alert"

    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { self.authorizationGranted = granted }
        }
    }

    func scheduleAlert(reason: String) {
        let content = UNMutableNotificationContent()
        content.title = "Posture Check"
        content.body = "\(reason). You've been in this position for over 30 seconds."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: alertIdentifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelAlert() {
        center.removePendingNotificationRequests(withIdentifiers: [alertIdentifier])
    }
}
