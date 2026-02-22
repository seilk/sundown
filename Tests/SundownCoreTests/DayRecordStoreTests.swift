import Foundation
import Testing
@testable import SundownCore

@Test
func load_whenNoDataSaved_thenReturnsNil() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsDayRecordStore(userDefaults: defaults)

    let record = store.load(dayId: "2026-02-22")

    #expect(record == nil)
}

@Test
func save_thenLoad_roundTripsDayRecord() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsDayRecordStore(userDefaults: defaults)
    var input = DayRecord(dayId: "2026-02-22", limitMinutes: 480)
    input.add(activity: .work, minutes: 90)

    store.save(input)
    let loaded = store.load(dayId: "2026-02-22")

    #expect(loaded == input)
}

@Test
func loadAll_returnsAllSavedRecordsSortedByDayId() {
    let defaults = isolatedDefaults()
    let store = UserDefaultsDayRecordStore(userDefaults: defaults)

    store.save(DayRecord(dayId: "2026-02-23", limitMinutes: 480))
    store.save(DayRecord(dayId: "2026-02-22", limitMinutes: 480))

    let all = store.loadAll()

    #expect(all.map(\.dayId) == ["2026-02-22", "2026-02-23"])
}

private func isolatedDefaults() -> UserDefaults {
    let suiteName = "SundownCoreTests.DayRecordStore.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Failed to create isolated UserDefaults suite")
        return .standard
    }

    defaults.removePersistentDomain(forName: suiteName)
    return defaults
}
