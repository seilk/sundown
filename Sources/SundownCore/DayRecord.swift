import Foundation

public struct RitualTotals: Equatable {
    public let workMinutes: Int
    public let breakMinutes: Int
    public let idleMinutes: Int
    public let totalMinutes: Int

    public init(workMinutes: Int, breakMinutes: Int, idleMinutes: Int) {
        self.workMinutes = max(0, workMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.idleMinutes = max(0, idleMinutes)
        self.totalMinutes = max(0, workMinutes) + max(0, breakMinutes) + max(0, idleMinutes)
    }
}

public struct DayRecord: Codable, Equatable {
    public let dayId: String
    public private(set) var workMinutes: Int
    public private(set) var breakMinutes: Int
    public private(set) var idleMinutes: Int
    public let limitMinutes: Int
    public private(set) var overMinutes: Int

    public init(
        dayId: String,
        workMinutes: Int = 0,
        breakMinutes: Int = 0,
        idleMinutes: Int = 0,
        limitMinutes: Int,
        overMinutes: Int = 0
    ) {
        self.dayId = dayId
        self.workMinutes = max(0, workMinutes)
        self.breakMinutes = max(0, breakMinutes)
        self.idleMinutes = max(0, idleMinutes)
        self.limitMinutes = max(0, limitMinutes)
        self.overMinutes = max(0, overMinutes)
        recalculateOverMinutes()
    }

    public mutating func add(activity: ActivityKind, minutes: Int) {
        let normalizedMinutes = max(0, minutes)
        switch activity {
        case .work:
            workMinutes += normalizedMinutes
        case .breakTime:
            breakMinutes += normalizedMinutes
        case .idle:
            idleMinutes += normalizedMinutes
        }

        recalculateOverMinutes()
    }

    public func ritualTotals() -> RitualTotals {
        RitualTotals(workMinutes: workMinutes, breakMinutes: breakMinutes, idleMinutes: idleMinutes)
    }

    private mutating func recalculateOverMinutes() {
        overMinutes = max(0, workMinutes - limitMinutes)
    }
}
