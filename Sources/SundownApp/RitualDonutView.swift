import SwiftUI

struct RitualDonutView: View {
    let workedSeconds: Int
    let limitMinutes: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 18)

                Circle()
                    .trim(from: 0, to: min(max(progressToLimit, 0.02), 1.0))
                    .stroke(progressGradient, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                if overflowProgress > 0 {
                    Circle()
                        .trim(from: 0, to: min(overflowProgress, 1.0))
                        .stroke(Color.black.opacity(0.85), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }

                VStack(spacing: 2) {
                    Text("WORKTIME")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(subtleText)

                    Text(workedHoursText)
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryText)

                    Text(deltaText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(deltaColor)
                }
            }
            .frame(width: 156, height: 156)

            Text("Target \(limitHoursText)")
                .font(.caption)
                .foregroundStyle(subtleText)
        }
    }

    private var progressToLimit: Double {
        let limitSeconds = max(1, limitMinutes * 60)
        guard limitMinutes > 0 else {
            return 0
        }

        return min(Double(workedSeconds) / Double(limitSeconds), 1.0)
    }

    private var overflowProgress: Double {
        let limitSeconds = max(1, limitMinutes * 60)
        guard limitMinutes > 0 else {
            return 0
        }

        let overflowSeconds = max(0, workedSeconds - limitSeconds)
        return Double(overflowSeconds) / Double(limitSeconds)
    }

    private var workedHoursText: String {
        String(format: "%.1fh", Double(workedSeconds) / 3600.0)
    }

    private var limitHoursText: String {
        String(format: "%.1fh", Double(limitMinutes) / 60.0)
    }

    private var deltaText: String {
        let deltaSeconds = workedSeconds - (limitMinutes * 60)
        if abs(deltaSeconds) < 60 {
            return "On target"
        }

        let sign = deltaSeconds > 0 ? "+" : "-"
        let direction = deltaSeconds > 0 ? "over" : "under"
        let hours = Double(abs(deltaSeconds)) / 3600.0
        return String(format: "%@%.1fh %@", sign, hours, direction)
    }

    private var deltaColor: Color {
        let deltaSeconds = workedSeconds - (limitMinutes * 60)
        if deltaSeconds > 0 {
            return Color(red: 0.93, green: 0.20, blue: 0.18)
        }

        if deltaSeconds < 0 {
            return Color(red: 0.12, green: 0.44, blue: 0.84)
        }

        return Color(red: 0.16, green: 0.72, blue: 0.34)
    }

    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                Color(red: 0.16, green: 0.72, blue: 0.34),
                Color(red: 0.18, green: 0.47, blue: 0.93),
                Color(red: 1.0, green: 0.62, blue: 0.10),
                Color(red: 0.93, green: 0.20, blue: 0.18),
                Color(red: 0.16, green: 0.72, blue: 0.34)
            ]),
            center: .center
        )
    }

    private var primaryText: Color {
        Color(red: 0.08, green: 0.12, blue: 0.10)
    }

    private var subtleText: Color {
        Color(red: 0.34, green: 0.40, blue: 0.36)
    }
}
