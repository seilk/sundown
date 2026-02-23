import Foundation

public struct DayBoundary {
    private let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func dayId(for date: Date, resetMinutesFromMidnight: Int) -> String {
        let resetClamped = min(max(resetMinutesFromMidnight, 0), 1_439)
        guard let shiftedDate = calendar.date(byAdding: .minute, value: -resetClamped, to: date) else {
            return formattedDay(calendar.startOfDay(for: date))
        }

        return formattedDay(calendar.startOfDay(for: shiftedDate))
    }

    private func formattedDay(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        let year = parts.year ?? 1970
        let month = parts.month ?? 1
        let day = parts.day ?? 1

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
