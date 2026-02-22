import Testing
@testable import SundownCore

@Test
func addingMinutes_accumulatesByActivity() {
    var record = DayRecord(dayId: "2026-02-22", limitMinutes: 480)

    record.add(activity: .work, minutes: 60)
    record.add(activity: .breakTime, minutes: 15)
    record.add(activity: .idle, minutes: 10)

    #expect(record.workMinutes == 60)
    #expect(record.breakMinutes == 15)
    #expect(record.idleMinutes == 10)
}

@Test
func addingWorkMinutes_updatesOverMinutesAgainstLimit() {
    var record = DayRecord(dayId: "2026-02-22", limitMinutes: 120)

    record.add(activity: .work, minutes: 150)

    #expect(record.overMinutes == 30)
}

@Test
func ritualTotals_returnsConsistentTotal() {
    var record = DayRecord(dayId: "2026-02-22", limitMinutes: 480)
    record.add(activity: .work, minutes: 30)
    record.add(activity: .breakTime, minutes: 20)
    record.add(activity: .idle, minutes: 10)

    let totals = record.ritualTotals()

    #expect(totals.totalMinutes == 60)
    #expect(totals.workMinutes == 30)
    #expect(totals.breakMinutes == 20)
    #expect(totals.idleMinutes == 10)
}
