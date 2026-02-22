import Foundation

public enum WorktimeState: Equatable {
    case underLimit(remainingSeconds: Int)
    case overLimit(overtimeSeconds: Int)
}

public struct WorktimeStateEvaluator {
    public init() {}

    public func evaluate(elapsedSeconds: Int, dailyLimitMinutes: Int) -> WorktimeState {
        let clampedElapsedSeconds = max(0, elapsedSeconds)
        let normalizedLimitSeconds = max(0, dailyLimitMinutes) * 60

        if clampedElapsedSeconds <= normalizedLimitSeconds {
            return .underLimit(remainingSeconds: normalizedLimitSeconds - clampedElapsedSeconds)
        }

        return .overLimit(overtimeSeconds: clampedElapsedSeconds - normalizedLimitSeconds)
    }
}

public struct WorktimeStateFormatter {
    public init() {}

    public func displayText(for state: WorktimeState) -> String {
        switch state {
        case let .underLimit(remainingSeconds):
            return "\(hours(from: remainingSeconds))h \(paddedMinutes(from: remainingSeconds))m \(paddedSeconds(from: remainingSeconds))s left"
        case let .overLimit(overtimeSeconds):
            return "+\(hours(from: overtimeSeconds))h \(paddedMinutes(from: overtimeSeconds))m \(paddedSeconds(from: overtimeSeconds))s"
        }
    }

    public func isOverLimit(_ state: WorktimeState) -> Bool {
        switch state {
        case .underLimit:
            return false
        case .overLimit:
            return true
        }
    }

    private func hours(from totalSeconds: Int) -> Int {
        totalSeconds / 3_600
    }

    private func paddedMinutes(from totalSeconds: Int) -> String {
        String(format: "%02d", (totalSeconds % 3_600) / 60)
    }

    private func paddedSeconds(from totalSeconds: Int) -> String {
        String(format: "%02d", totalSeconds % 60)
    }
}
