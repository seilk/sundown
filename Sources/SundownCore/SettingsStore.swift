import Foundation

public struct PersistedSettings: Equatable {
    public let dailyLimitMinutes: Int?
    public let dayResetMinutesFromMidnight: Int?
    public let notificationsEnabled: Bool?
    public let idleThresholdMinutes: Int?
    public let overLimitReminderMinutes: Int?
    public let menuBarDisplayModeRawValue: Int?

    public init(
        dailyLimitMinutes: Int?,
        dayResetMinutesFromMidnight: Int?,
        notificationsEnabled: Bool?,
        idleThresholdMinutes: Int?,
        overLimitReminderMinutes: Int?,
        menuBarDisplayModeRawValue: Int? = nil
    ) {
        self.dailyLimitMinutes = dailyLimitMinutes
        self.dayResetMinutesFromMidnight = dayResetMinutesFromMidnight
        self.notificationsEnabled = notificationsEnabled
        self.idleThresholdMinutes = idleThresholdMinutes
        self.overLimitReminderMinutes = overLimitReminderMinutes
        self.menuBarDisplayModeRawValue = menuBarDisplayModeRawValue
    }
}

public protocol SettingsStore {
    func load() -> PersistedSettings
    func save(_ settings: PersistedSettings)
}

public final class UserDefaultsSettingsStore: SettingsStore {
    private enum Keys {
        static let dailyLimitMinutes = "dailyLimitMinutes"
        static let dayResetMinutes = "dayResetMinutes"
        static let notificationsEnabled = "notificationsEnabled"
        static let idleThresholdMinutes = "idleThresholdMinutes"
        static let overLimitReminderMinutes = "overLimitReminderMinutes"
        static let menuBarDisplayModeRawValue = "menuBarDisplayModeRawValue"
    }

    private let userDefaults: UserDefaults

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load() -> PersistedSettings {
        PersistedSettings(
            dailyLimitMinutes: intValue(forKey: Keys.dailyLimitMinutes),
            dayResetMinutesFromMidnight: intValue(forKey: Keys.dayResetMinutes),
            notificationsEnabled: boolValue(forKey: Keys.notificationsEnabled) ?? false,
            idleThresholdMinutes: intValue(forKey: Keys.idleThresholdMinutes),
            overLimitReminderMinutes: intValue(forKey: Keys.overLimitReminderMinutes),
            menuBarDisplayModeRawValue: intValue(forKey: Keys.menuBarDisplayModeRawValue)
        )
    }

    public func save(_ settings: PersistedSettings) {
        setIntValue(settings.dailyLimitMinutes, forKey: Keys.dailyLimitMinutes)
        setIntValue(settings.dayResetMinutesFromMidnight, forKey: Keys.dayResetMinutes)
        setBoolValue(settings.notificationsEnabled, forKey: Keys.notificationsEnabled)
        setIntValue(settings.idleThresholdMinutes, forKey: Keys.idleThresholdMinutes)
        setIntValue(settings.overLimitReminderMinutes, forKey: Keys.overLimitReminderMinutes)
        setIntValue(settings.menuBarDisplayModeRawValue, forKey: Keys.menuBarDisplayModeRawValue)
    }

    private func intValue(forKey key: String) -> Int? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }

        return userDefaults.integer(forKey: key)
    }

    private func boolValue(forKey key: String) -> Bool? {
        guard userDefaults.object(forKey: key) != nil else {
            return nil
        }

        return userDefaults.bool(forKey: key)
    }

    private func setIntValue(_ value: Int?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }

    private func setBoolValue(_ value: Bool?, forKey key: String) {
        if let value {
            userDefaults.set(value, forKey: key)
        } else {
            userDefaults.removeObject(forKey: key)
        }
    }
}
