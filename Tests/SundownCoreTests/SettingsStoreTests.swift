import Foundation
import Testing
@testable import SundownCore

@Test
func load_whenNothingSaved_thenReturnsNilForAllFields() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsSettingsStore(userDefaults: defaults)

    let settings = store.load()

    #expect(settings.dailyLimitMinutes == nil)
    #expect(settings.dayResetMinutesFromMidnight == nil)
    #expect(settings.notificationsEnabled == false)
    #expect(settings.idleThresholdMinutes == nil)
    #expect(settings.overLimitReminderMinutes == nil)
    #expect(settings.menuBarDisplayModeRawValue == nil)
}

@Test
func save_thenLoad_roundTripsAllSettingsFields() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsSettingsStore(userDefaults: defaults)
    let input = PersistedSettings(
        dailyLimitMinutes: 480,
        dayResetMinutesFromMidnight: 240,
        notificationsEnabled: true,
        idleThresholdMinutes: 5,
        overLimitReminderMinutes: 30,
        menuBarDisplayModeRawValue: 1
    )

    store.save(input)
    let loaded = store.load()

    #expect(loaded == input)
}

@Test
func save_whenFieldIsNil_thenClearsStoredValue() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsSettingsStore(userDefaults: defaults)

    store.save(
        PersistedSettings(
            dailyLimitMinutes: 480,
            dayResetMinutesFromMidnight: 240,
            notificationsEnabled: true,
            idleThresholdMinutes: 5,
            overLimitReminderMinutes: 30,
            menuBarDisplayModeRawValue: 1
        )
    )

    store.save(
        PersistedSettings(
            dailyLimitMinutes: nil,
            dayResetMinutesFromMidnight: nil,
            notificationsEnabled: nil,
            idleThresholdMinutes: nil,
            overLimitReminderMinutes: nil,
            menuBarDisplayModeRawValue: nil
        )
    )

    let loaded = store.load()
    #expect(loaded.dailyLimitMinutes == nil)
    #expect(loaded.dayResetMinutesFromMidnight == nil)
    #expect(loaded.notificationsEnabled == false)
    #expect(loaded.idleThresholdMinutes == nil)
    #expect(loaded.overLimitReminderMinutes == nil)
    #expect(loaded.menuBarDisplayModeRawValue == nil)
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "SundownCoreTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Failed to create isolated UserDefaults suite")
        return .standard
    }

    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
