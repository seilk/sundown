import AppKit
import SundownCore

enum StatusIconTheme {
    case sunset
}

enum StatusIconPhase {
    case onboarding
    case normal
    case nearLimit
    case overLimit
}

enum MenuBarDisplayMode: Int, CaseIterable {
    case icon = 0
    case numeric = 1

    var label: String {
        switch self {
        case .icon:
            return "Icon"
        case .numeric:
            return "Numeric"
        }
    }
}

struct StatusIconSnapshot {
    let gateState: OnboardingGateState
    let worktimeState: WorktimeState?
    let dailyLimitMinutes: Int?
    let menuTitle: String
    let menuBarDisplayMode: MenuBarDisplayMode
}

struct StatusIconAppearance {
    let image: NSImage
    let title: String
    let titleColor: NSColor
    let showsIcon: Bool
    let toolTip: String
}

final class StatusIconRenderer {
    private let theme: StatusIconTheme

    private let nearLimitProgressEnter = 0.85
    private let nearLimitProgressExit = 0.82
    private let nearLimitSecondsEnter = 1_800
    private let nearLimitSecondsExit = 2_100

    init(theme: StatusIconTheme = .sunset) {
        self.theme = theme
    }

    func render(snapshot: StatusIconSnapshot, previousPhase: StatusIconPhase) -> (StatusIconAppearance, StatusIconPhase) {
        let phase = resolvedPhase(snapshot: snapshot, previousPhase: previousPhase)
        let color = color(for: snapshot, phase: phase)
        let image = symbolImage(color: color)
        let title = statusTitleText(snapshot: snapshot)
        let showsIcon = snapshot.menuBarDisplayMode == .icon
        let toolTip = toolTipText(snapshot: snapshot, phase: phase)

        return (
            StatusIconAppearance(
                image: image,
                title: title,
                titleColor: color,
                showsIcon: showsIcon,
                toolTip: toolTip
            ),
            phase
        )
    }

    private func resolvedPhase(snapshot: StatusIconSnapshot, previousPhase: StatusIconPhase) -> StatusIconPhase {
        guard snapshot.gateState == .allowed else {
            return .onboarding
        }

        guard let worktimeState = snapshot.worktimeState,
              let dailyLimitMinutes = snapshot.dailyLimitMinutes,
              dailyLimitMinutes > 0 else {
            return .onboarding
        }

        switch worktimeState {
        case .overLimit:
            return .overLimit

        case let .underLimit(remainingSeconds):
            let limitSeconds = dailyLimitMinutes * 60
            let elapsedSeconds = max(0, limitSeconds - remainingSeconds)
            let progress = Double(elapsedSeconds) / Double(max(1, limitSeconds))

            if previousPhase == .nearLimit {
                if progress < nearLimitProgressExit && remainingSeconds > nearLimitSecondsExit {
                    return .normal
                }

                return .nearLimit
            }

            if progress >= nearLimitProgressEnter || remainingSeconds <= nearLimitSecondsEnter {
                return .nearLimit
            }

            return .normal
        }
    }

    private func symbolName() -> String {
        switch theme {
        case .sunset:
            return "sun.horizon.fill"
        }
    }

    private func color(for snapshot: StatusIconSnapshot, phase: StatusIconPhase) -> NSColor {
        switch theme {
        case .sunset:
            if phase == .onboarding {
                return NSColor(red: 0.52, green: 0.55, blue: 0.58, alpha: 1.0)
            }

            guard let worktimeState = snapshot.worktimeState,
                  let dailyLimitMinutes = snapshot.dailyLimitMinutes,
                  dailyLimitMinutes > 0 else {
                return NSColor(red: 0.52, green: 0.55, blue: 0.58, alpha: 1.0)
            }

            switch worktimeState {
            case .overLimit:
                return NSColor(red: 0.93, green: 0.20, blue: 0.18, alpha: 1.0)

            case let .underLimit(remainingSeconds):
                let limitSeconds = dailyLimitMinutes * 60
                let elapsedSeconds = max(0, limitSeconds - remainingSeconds)
                let progress = Double(elapsedSeconds) / Double(max(1, limitSeconds))
                return gradientColor(progress: progress)
            }
        }
    }

    private func statusTitleText(snapshot: StatusIconSnapshot) -> String {
        guard snapshot.gateState == .allowed,
              let worktimeState = snapshot.worktimeState else {
            return "SET"
        }

        guard snapshot.menuBarDisplayMode == .numeric else {
            return ""
        }

        switch worktimeState {
        case let .underLimit(remainingSeconds):
            return formatNumericDuration(seconds: remainingSeconds, isOver: false)
        case let .overLimit(overtimeSeconds):
            return formatNumericDuration(seconds: overtimeSeconds, isOver: true)
        }
    }

    private func toolTipText(snapshot: StatusIconSnapshot, phase: StatusIconPhase) -> String {
        switch phase {
        case .onboarding:
            return "Sundown - \(snapshot.menuTitle)"

        case .normal, .nearLimit:
            if case let .underLimit(remainingSeconds) = snapshot.worktimeState {
                let remaining = formatDuration(seconds: remainingSeconds)
                if phase == .nearLimit {
                    return "Sundown - Approaching limit (\(remaining) left)"
                }

                return "Sundown - \(remaining) left"
            }

            return "Sundown"

        case .overLimit:
            if case let .overLimit(overtimeSeconds) = snapshot.worktimeState {
                return "Sundown - Over by \(formatDuration(seconds: overtimeSeconds))"
            }

            return "Sundown - Over limit"
        }
    }

    private func symbolImage(color: NSColor) -> NSImage {
        let symbolName = symbolName()
        let sizeConfiguration = NSImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let colorConfiguration = NSImage.SymbolConfiguration(paletteColors: [color])
        
        // Use sun.horizon.fill as primary, fallback to sun.max.fill if widely unavailable (unlikely on modern macOS)
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Sundown")
            ?? NSImage(systemSymbolName: "sun.max.fill", accessibilityDescription: "Sundown")
            ?? NSImage()

        let sized = base.withSymbolConfiguration(sizeConfiguration) ?? base
        let resolved = sized.withSymbolConfiguration(colorConfiguration) ?? sized
        resolved.isTemplate = false // Force specific color rendering
        return resolved
    }

    private func gradientColor(progress: Double) -> NSColor {
        let normalized = min(max(progress, 0.0), 1.0)
        let anchors: [(Double, NSColor)] = [
            (0.0, NSColor(red: 0.16, green: 0.72, blue: 0.34, alpha: 1.0)),
            (0.45, NSColor(red: 0.18, green: 0.47, blue: 0.93, alpha: 1.0)),
            (0.85, NSColor(red: 1.0, green: 0.62, blue: 0.10, alpha: 1.0)),
            (1.0, NSColor(red: 0.93, green: 0.20, blue: 0.18, alpha: 1.0))
        ]

        for index in 0..<(anchors.count - 1) {
            let current = anchors[index]
            let next = anchors[index + 1]
            if normalized >= current.0 && normalized <= next.0 {
                let localT = (normalized - current.0) / (next.0 - current.0)
                return interpolateColor(from: current.1, to: next.1, t: localT)
            }
        }

        return anchors.last?.1 ?? .systemRed
    }

    private func interpolateColor(from: NSColor, to: NSColor, t: Double) -> NSColor {
        let clamped = min(max(t, 0.0), 1.0)
        let start = from.usingColorSpace(.sRGB) ?? from
        let end = to.usingColorSpace(.sRGB) ?? to

        let red = start.redComponent + CGFloat(clamped) * (end.redComponent - start.redComponent)
        let green = start.greenComponent + CGFloat(clamped) * (end.greenComponent - start.greenComponent)
        let blue = start.blueComponent + CGFloat(clamped) * (end.blueComponent - start.blueComponent)

        return NSColor(red: red, green: green, blue: blue, alpha: 1.0)
    }

    private func formatHoursOneDecimal(seconds: Int) -> String {
        let hours = Double(max(0, seconds)) / 3_600.0
        return String(format: "%.1f", hours)
    }

    private func formatNumericDuration(seconds: Int, isOver: Bool) -> String {
        let normalized = max(0, seconds)
        if normalized < 3_600 {
            let minutes = normalized / 60
            if minutes == 0 {
                return "0m"
            }
            return isOver ? "+\(minutes)m" : "-\(minutes)m"
        }

        let hourText = "\(formatHoursOneDecimal(seconds: normalized))h"
        return isOver ? "+\(hourText)" : "-\(hourText)"
    }

    private func formatDuration(seconds: Int) -> String {
        let normalized = max(0, seconds)
        let hours = normalized / 3_600
        let minutes = (normalized % 3_600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        }

        return String(format: "%dm", minutes)
    }
}
