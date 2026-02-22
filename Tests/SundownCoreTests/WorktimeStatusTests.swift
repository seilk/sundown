import Testing
@testable import SundownCore

@Test
func evaluate_whenElapsedIsUnderLimit_thenReturnsRemainingState() {
    let state = WorktimeStateEvaluator().evaluate(elapsedSeconds: 9_420, dailyLimitMinutes: 480)

    #expect(state == .underLimit(remainingSeconds: 19_380))
}

@Test
func evaluate_whenElapsedIsEqualToLimit_thenReturnsZeroRemaining() {
    let state = WorktimeStateEvaluator().evaluate(elapsedSeconds: 28_800, dailyLimitMinutes: 480)

    #expect(state == .underLimit(remainingSeconds: 0))
}

@Test
func evaluate_whenElapsedIsOverLimit_thenReturnsOvertimeState() {
    let state = WorktimeStateEvaluator().evaluate(elapsedSeconds: 31_020, dailyLimitMinutes: 480)

    #expect(state == .overLimit(overtimeSeconds: 2_220))
}

@Test
func displayText_whenUnderLimit_thenFormatsAsHoursMinutesSecondsLeft() {
    let text = WorktimeStateFormatter().displayText(for: .underLimit(remainingSeconds: 8_298))

    #expect(text == "2h 18m 18s left")
}

@Test
func displayText_whenOverLimit_thenFormatsAsPlusHoursMinutesSeconds() {
    let text = WorktimeStateFormatter().displayText(for: .overLimit(overtimeSeconds: 2_220))

    #expect(text == "+0h 37m 00s")
}

@Test
func isOverLimit_whenUnderLimit_thenReturnsFalse() {
    let value = WorktimeStateFormatter().isOverLimit(.underLimit(remainingSeconds: 5))

    #expect(value == false)
}

@Test
func isOverLimit_whenOverLimit_thenReturnsTrue() {
    let value = WorktimeStateFormatter().isOverLimit(.overLimit(overtimeSeconds: 1))

    #expect(value == true)
}
