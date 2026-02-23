import Foundation

public struct WorktimeDurationFormatter {
    public init() {}

    public func hoursOneDecimal(from seconds: Int) -> String {
        let hours = Double(max(0, seconds)) / 3_600.0
        return String(format: "%.1f", hours)
    }

    public func numericDuration(seconds: Int, isOver: Bool) -> String {
        let normalized = max(0, seconds)
        if normalized < 3_600 {
            let minutes = normalized / 60
            if minutes == 0 {
                return "0m"
            }

            return isOver ? "+\(minutes)m" : "-\(minutes)m"
        }

        let hoursText = "\(hoursOneDecimal(from: normalized))h"
        return isOver ? "+\(hoursText)" : "-\(hoursText)"
    }

    public func compactDuration(seconds: Int) -> String {
        let normalized = max(0, seconds)
        let hours = normalized / 3_600
        let minutes = (normalized % 3_600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        return String(format: "%dm", minutes)
    }

    public func detailedDuration(seconds: Int) -> String {
        let normalized = max(0, seconds)
        let hours = normalized / 3_600
        let minutes = (normalized % 3_600) / 60
        let remainingSeconds = normalized % 60
        return String(format: "%dh %02dm %02ds", hours, minutes, remainingSeconds)
    }
}
