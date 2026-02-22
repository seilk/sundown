import Testing
@testable import SundownCore

@Test
func classify_whenBreakModeEnabled_thenReturnsBreak() {
    let classifier = ActivityClassifier()
    let activity = classifier.classify(isBreakActive: true, inactivitySeconds: 0, idleThresholdMinutes: 5)

    #expect(activity == .breakTime)
}

@Test
func classify_whenInactivityAtThreshold_thenReturnsIdle() {
    let classifier = ActivityClassifier()
    let activity = classifier.classify(isBreakActive: false, inactivitySeconds: 300, idleThresholdMinutes: 5)

    #expect(activity == .idle)
}

@Test
func classify_whenInactivityBelowThreshold_thenReturnsWork() {
    let classifier = ActivityClassifier()
    let activity = classifier.classify(isBreakActive: false, inactivitySeconds: 299, idleThresholdMinutes: 5)

    #expect(activity == .work)
}
