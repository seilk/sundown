import Foundation
import Testing
@testable import SundownCore

@Test
func dayId_whenResetMissing_thenReturnsNil() {
    let engine = TimeEngine()
    let settings = PersistedSettings(
        dailyLimitMinutes: 480,
        dayResetMinutesFromMidnight: nil,
        notificationsEnabled: false,
        idleThresholdMinutes: 5,
        overLimitReminderMinutes: 30
    )

    let value = engine.dayId(now: Date(), settings: settings)

    #expect(value == nil)
}

@Test
func worktimeState_whenLimitMissing_thenReturnsNil() {
    let engine = TimeEngine()
    let settings = PersistedSettings(
        dailyLimitMinutes: nil,
        dayResetMinutesFromMidnight: 240,
        notificationsEnabled: false,
        idleThresholdMinutes: 5,
        overLimitReminderMinutes: 30
    )

    let value = engine.worktimeState(elapsedSeconds: 1_000, settings: settings)

    #expect(value == nil)
}

@Test
func activity_whenThresholdNotSet_thenUsesDefaultFiveMinutes() {
    let engine = TimeEngine()
    let settings = PersistedSettings(
        dailyLimitMinutes: 480,
        dayResetMinutesFromMidnight: 240,
        notificationsEnabled: false,
        idleThresholdMinutes: nil,
        overLimitReminderMinutes: nil
    )

    let value = engine.activity(isBreakActive: false, inactivitySeconds: 300, settings: settings)

    #expect(value == .idle)
}

@Test
func reminderInterval_whenNotSet_thenDefaultsToThirty() {
    let engine = TimeEngine()
    let settings = PersistedSettings(
        dailyLimitMinutes: 480,
        dayResetMinutesFromMidnight: 240,
        notificationsEnabled: false,
        idleThresholdMinutes: 5,
        overLimitReminderMinutes: nil
    )

    let value = engine.reminderIntervalMinutes(settings: settings)

    #expect(value == 30)
}
