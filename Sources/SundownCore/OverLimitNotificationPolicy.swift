import Foundation

public struct OverLimitNotificationPolicy {
    public init() {}

    public func shouldNotify(
        notificationsEnabled: Bool?,
        isOverLimit: Bool,
        wasOverLimit: Bool,
        now: Date,
        lastNotificationAt: Date?,
        reminderIntervalMinutes: Int = 30
    ) -> Bool {
        guard notificationsEnabled == true else {
            return false
        }

        guard isOverLimit else {
            return false
        }

        if !wasOverLimit {
            return true
        }

        guard let lastNotificationAt else {
            return true
        }

        let intervalSeconds = max(1, reminderIntervalMinutes) * 60
        return now.timeIntervalSince(lastNotificationAt) >= Double(intervalSeconds)
    }
}
