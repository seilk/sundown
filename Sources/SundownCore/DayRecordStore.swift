import Foundation

public protocol DayRecordStore {
    func load(dayId: String) -> DayRecord?
    func loadAll() -> [DayRecord]
    func save(_ record: DayRecord)
}

public final class UserDefaultsDayRecordStore: DayRecordStore {
    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let dayRecords = "dayRecords.v1"
    }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    public func load(dayId: String) -> DayRecord? {
        loadMap()[dayId]
    }

    public func loadAll() -> [DayRecord] {
        loadMap().values.sorted { $0.dayId < $1.dayId }
    }

    public func save(_ record: DayRecord) {
        var map = loadMap()
        map[record.dayId] = record

        guard let encoded = try? encoder.encode(map) else {
            return
        }

        userDefaults.set(encoded, forKey: Keys.dayRecords)
    }

    private func loadMap() -> [String: DayRecord] {
        guard let data = userDefaults.data(forKey: Keys.dayRecords) else {
            return [:]
        }

        guard let map = try? decoder.decode([String: DayRecord].self, from: data) else {
            return [:]
        }

        return map
    }
}
