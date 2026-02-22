import Foundation
import UserNotifications

public protocol NotificationService {
    func requestAuthorizationIfNeeded()
    func sendOverLimitNotification(message: String)
}

public final class UserNotificationCenterService: NotificationService {
    private let centerProvider: () -> UNUserNotificationCenter

    public init(centerProvider: @escaping () -> UNUserNotificationCenter = { UNUserNotificationCenter.current() }) {
        self.centerProvider = centerProvider
    }

    public func requestAuthorizationIfNeeded() {
        let center = centerProvider()
        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    public func sendOverLimitNotification(message: String) {
        let center = centerProvider()
        let content = UNMutableNotificationContent()
        content.title = "Sundown"
        content.body = message
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        center.add(request) { _ in }
    }
}
