public enum ActivityKind: Equatable {
    case work
    case breakTime
    case idle
}

public struct ActivityClassifier {
    public init() {}

    public func classify(isBreakActive: Bool, inactivitySeconds: Int, idleThresholdMinutes: Int) -> ActivityKind {
        if isBreakActive {
            return .breakTime
        }

        let thresholdSeconds = max(1, idleThresholdMinutes) * 60
        if max(0, inactivitySeconds) >= thresholdSeconds {
            return .idle
        }

        return .work
    }
}
