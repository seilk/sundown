import Foundation
import Testing
@testable import SundownCore

@Test
func shouldNotify_whenNotificationsDisabled_thenReturnsFalse() {
    let policy = OverLimitNotificationPolicy()
    let result = policy.shouldNotify(
        notificationsEnabled: false,
        isOverLimit: true,
        wasOverLimit: true,
        now: Date(),
        lastNotificationAt: nil
    )

    #expect(result == false)
}

@Test
func shouldNotify_whenNotificationsUnset_thenReturnsFalse() {
    let policy = OverLimitNotificationPolicy()
    let result = policy.shouldNotify(
        notificationsEnabled: nil,
        isOverLimit: true,
        wasOverLimit: true,
        now: Date(),
        lastNotificationAt: nil
    )

    #expect(result == false)
}

@Test
func shouldNotify_whenNotOverLimit_thenReturnsFalse() {
    let policy = OverLimitNotificationPolicy()
    let result = policy.shouldNotify(
        notificationsEnabled: true,
        isOverLimit: false,
        wasOverLimit: false,
        now: Date(),
        lastNotificationAt: nil
    )

    #expect(result == false)
}

@Test
func shouldNotify_whenJustCrossedIntoOverLimit_thenReturnsTrue() {
    let policy = OverLimitNotificationPolicy()
    let result = policy.shouldNotify(
        notificationsEnabled: true,
        isOverLimit: true,
        wasOverLimit: false,
        now: Date(),
        lastNotificationAt: nil
    )

    #expect(result == true)
}

@Test
func shouldNotify_whenOverLimitAndNoHistory_thenReturnsTrue() {
    let policy = OverLimitNotificationPolicy()
    let result = policy.shouldNotify(
        notificationsEnabled: true,
        isOverLimit: true,
        wasOverLimit: true,
        now: Date(),
        lastNotificationAt: nil
    )

    #expect(result == true)
}

@Test
func shouldNotify_whenOverLimitAnd30MinutesPassed_thenReturnsTrue() {
    let policy = OverLimitNotificationPolicy()
    let now = Date(timeIntervalSince1970: 1_000)
    let last = now.addingTimeInterval(-1_800)

    let result = policy.shouldNotify(
        notificationsEnabled: true,
        isOverLimit: true,
        wasOverLimit: true,
        now: now,
        lastNotificationAt: last
    )

    #expect(result == true)
}

@Test
func shouldNotify_whenOverLimitButIntervalNotReached_thenReturnsFalse() {
    let policy = OverLimitNotificationPolicy()
    let now = Date(timeIntervalSince1970: 1_000)
    let last = now.addingTimeInterval(-1_799)

    let result = policy.shouldNotify(
        notificationsEnabled: true,
        isOverLimit: true,
        wasOverLimit: true,
        now: now,
        lastNotificationAt: last
    )

    #expect(result == false)
}
