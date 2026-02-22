import Foundation
import Testing
@testable import SundownCore

@Test
func dayId_whenTimeIsAfterReset_thenReturnsSameCalendarDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let boundary = DayBoundary(calendar: calendar)

    let date = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 12, minute: 0, second: 0))!
    let dayId = boundary.dayId(for: date, resetMinutesFromMidnight: 240)

    #expect(dayId == "2024-01-31")
}

@Test
func dayId_whenTimeIsBeforeReset_thenReturnsPreviousDay() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let boundary = DayBoundary(calendar: calendar)

    let date = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31, hour: 4, minute: 0, second: 0))!
    let dayId = boundary.dayId(for: date, resetMinutesFromMidnight: 300)

    #expect(dayId == "2024-01-30")
}
