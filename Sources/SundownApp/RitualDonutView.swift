import SwiftUI

struct RitualDonutView: View {
    let workedSeconds: Int
    let limitMinutes: Int

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background track
                Circle()
                    .stroke(UIStyle.borderSubtle, lineWidth: 20)

                // Progress arc
                Circle()
                    .trim(from: 0, to: progressToLimit)
                    .stroke(progressGradient, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: progressColor.opacity(0.3), radius: 8, x: 0, y: 4)
                    .animation(.spring(response: 0.45, dampingFraction: 0.84), value: progressToLimit)

                // Overflow arc
                if safeWorkedSeconds > limitSeconds {
                    Circle()
                        .trim(from: 0, to: overflowProgress)
                        .stroke(UIStyle.alertText, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .shadow(color: UIStyle.alertText.opacity(0.3), radius: 8, x: 0, y: 4)
                        .animation(.spring(response: 0.45, dampingFraction: 0.84), value: overflowProgress)
                }

                VStack(spacing: 0) {
                    Text("WORKTIME")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(UIStyle.tertiaryText)
                        .padding(.bottom, 2)

                    Text(workedHoursText)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(UIStyle.primaryText)
                        .contentTransition(.numericText())

                    Text(deltaText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(deltaColor)
                        .padding(.top, 2)
                }
            }
            .frame(width: 180, height: 180)

            Text("Target \(limitHoursText)")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(UIStyle.secondaryText)
                .padding(.top, 8)
        }
    }

    private var progressToLimit: Double {
        min(max(Double(safeWorkedSeconds) / Double(limitSeconds), 0.0), 1.0)
    }

    private var overflowProgress: Double {
        let overflowSeconds = max(0, safeWorkedSeconds - limitSeconds)
        return min(max(Double(overflowSeconds) / Double(limitSeconds), 0.0), 1.0)
    }

    private var workedHoursText: String {
        String(format: "%.1fh", Double(safeWorkedSeconds) / 3600.0)
    }

    private var limitHoursText: String {
        String(format: "%.1fh", Double(limitMinutes) / 60.0)
    }

    private var deltaText: String {
        let deltaSeconds = safeWorkedSeconds - limitSeconds
        if abs(deltaSeconds) < 60 {
            return "On target"
        }

        let sign = deltaSeconds > 0 ? "+" : "-"
        let direction = deltaSeconds > 0 ? "over" : "under"
        let hours = Double(abs(deltaSeconds)) / 3600.0
        return String(format: "%@%.1fh %@", sign, hours, direction)
    }

    private var deltaColor: Color {
        let deltaSeconds = safeWorkedSeconds - limitSeconds
        if deltaSeconds > 0 {
            return UIStyle.alertText
        }

        if deltaSeconds < 0 {
            return UIStyle.activeBlue
        }

        return UIStyle.successText
    }

    private var progressColor: Color {
        let progress = Double(safeWorkedSeconds) / Double(limitSeconds)
        if progress >= 1.0 {
            return UIStyle.successText
        } else if progress > 0.8 {
            return UIStyle.warningAmber
        } else {
            return UIStyle.activeBlue
        }
    }

    private var progressGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: [
                UIStyle.activeBlue,
                UIStyle.accentCyan,
                UIStyle.successText
            ]),
            center: .center
        )
    }

    private var safeWorkedSeconds: Int {
        max(0, workedSeconds)
    }

    private var limitSeconds: Int {
        max(1, limitMinutes * 60)
    }
}
