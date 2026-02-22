import Testing
@testable import SundownCore

@Test
func evaluate_whenDailyLimitMissing_thenBlocksUsage() {
    let settings = OnboardingSettings(dailyLimitMinutes: nil, dayResetMinutesFromMidnight: 480)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .blockedMissingDailyLimit)
}

@Test
func evaluate_whenResetTimeMissing_thenBlocksUsage() {
    let settings = OnboardingSettings(dailyLimitMinutes: 480, dayResetMinutesFromMidnight: nil)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .blockedMissingResetTime)
}

@Test
func evaluate_whenDailyLimitIsZero_thenBlocksUsageAsInvalidLimit() {
    let settings = OnboardingSettings(dailyLimitMinutes: 0, dayResetMinutesFromMidnight: 480)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .blockedInvalidDailyLimit)
}

@Test
func evaluate_whenResetTimeIsNegative_thenBlocksUsageAsInvalidResetTime() {
    let settings = OnboardingSettings(dailyLimitMinutes: 480, dayResetMinutesFromMidnight: -1)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .blockedInvalidResetTime)
}

@Test
func evaluate_whenResetTimeIs1440_thenBlocksUsageAsInvalidResetTime() {
    let settings = OnboardingSettings(dailyLimitMinutes: 480, dayResetMinutesFromMidnight: 1_440)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .blockedInvalidResetTime)
}

@Test
func evaluate_whenBothFieldsSet_thenAllowsUsage() {
    let settings = OnboardingSettings(dailyLimitMinutes: 480, dayResetMinutesFromMidnight: 240)

    let state = OnboardingGateEvaluator().evaluate(settings)

    #expect(state == .allowed)
}
