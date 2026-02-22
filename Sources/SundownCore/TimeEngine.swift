import Foundation

public struct TimeEngine {
    private let dayBoundary: DayBoundary
    private let worktimeStateEvaluator: WorktimeStateEvaluator
    private let activityClassifier: ActivityClassifier

    public init(
        dayBoundary: DayBoundary = DayBoundary(),
        worktimeStateEvaluator: WorktimeStateEvaluator = WorktimeStateEvaluator(),
        activityClassifier: ActivityClassifier = ActivityClassifier()
    ) {
        self.dayBoundary = dayBoundary
        self.worktimeStateEvaluator = worktimeStateEvaluator
        self.activityClassifier = activityClassifier
    }

    public func dayId(now: Date, settings: PersistedSettings) -> String? {
        guard let resetMinutes = settings.dayResetMinutesFromMidnight else {
            return nil
        }

        return dayBoundary.dayId(for: now, resetMinutesFromMidnight: resetMinutes)
    }

    public func worktimeState(elapsedSeconds: Int, settings: PersistedSettings) -> WorktimeState? {
        guard let dailyLimitMinutes = settings.dailyLimitMinutes else {
            return nil
        }

        return worktimeStateEvaluator.evaluate(
            elapsedSeconds: elapsedSeconds,
            dailyLimitMinutes: dailyLimitMinutes
        )
    }

    public func activity(isBreakActive: Bool, inactivitySeconds: Int, settings: PersistedSettings) -> ActivityKind {
        let idleThresholdMinutes = max(1, settings.idleThresholdMinutes ?? 5)
        return activityClassifier.classify(
            isBreakActive: isBreakActive,
            inactivitySeconds: inactivitySeconds,
            idleThresholdMinutes: idleThresholdMinutes
        )
    }

    public func reminderIntervalMinutes(settings: PersistedSettings) -> Int {
        max(1, settings.overLimitReminderMinutes ?? 30)
    }
}
