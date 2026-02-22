import Foundation

public struct DayBoundary {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func dayId(for date: Date, resetMinutesFromMidnight: Int) -> String {
        let resetClamped = min(max(resetMinutesFromMidnight, 0), 1_439)
        let startOfDate = calendar.startOfDay(for: date)
        let minutesSinceMidnight = calendar.dateComponents([.minute], from: startOfDate, to: date).minute ?? 0
        let offsetDays = minutesSinceMidnight < resetClamped ? -1 : 0

        guard let sundownDay = calendar.date(byAdding: .day, value: offsetDays, to: startOfDate) else {
            return formattedDay(startOfDate)
        }

        return formattedDay(sundownDay)
    }

    private func formattedDay(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let day = parts.day ?? 1

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
