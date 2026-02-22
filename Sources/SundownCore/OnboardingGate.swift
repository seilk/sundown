public struct OnboardingSettings: Equatable {
    public let dailyLimitMinutes: Int?
    public let dayResetMinutesFromMidnight: Int?

    public init(dailyLimitMinutes: Int?, dayResetMinutesFromMidnight: Int?) {
        self.dailyLimitMinutes = dailyLimitMinutes
        self.dayResetMinutesFromMidnight = dayResetMinutesFromMidnight
    }
}

public enum OnboardingGateState: Equatable {
    case blockedMissingDailyLimit
    case blockedInvalidDailyLimit
    case blockedMissingResetTime
    case blockedInvalidResetTime
    case allowed
}

public struct OnboardingGateEvaluator {
    public init() {}

    public func evaluate(_ settings: OnboardingSettings) -> OnboardingGateState {
        guard let dailyLimitMinutes = settings.dailyLimitMinutes else {
            return .blockedMissingDailyLimit
        }

        guard dailyLimitMinutes > 0 else {
            return .blockedInvalidDailyLimit
        }

        guard let dayResetMinutesFromMidnight = settings.dayResetMinutesFromMidnight else {
            return .blockedMissingResetTime
        }

        guard (0..<1_440).contains(dayResetMinutesFromMidnight) else {
            return .blockedInvalidResetTime
        }

        return .allowed
    }
}
