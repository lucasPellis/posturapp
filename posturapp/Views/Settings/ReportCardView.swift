import SwiftUI

struct ReportCardView: View {

    let report: PostureReport
    var compact = false

    private var bgColors: [Color] {
        switch report.score {
        case 85...: return [Color(red:0.05,green:0.18,blue:0.12), Color(red:0.02,green:0.10,blue:0.07)]
        case 70..<85: return [Color(red:0.10,green:0.14,blue:0.28), Color(red:0.06,green:0.09,blue:0.20)]
        case 50..<70: return [Color(red:0.25,green:0.15,blue:0.02), Color(red:0.15,green:0.08,blue:0.01)]
        case 30..<50: return [Color(red:0.28,green:0.10,blue:0.02), Color(red:0.18,green:0.05,blue:0.01)]
        default:      return [Color(red:0.28,green:0.04,blue:0.04), Color(red:0.16,green:0.02,blue:0.02)]
        }
    }

    private var accentColor: Color {
        switch report.score {
        case 85...: return .green
        case 70..<85: return Color(red:0.4,green:0.6,blue:1.0)
        case 50..<70: return .orange
        case 30..<50: return Color(red:1.0,green:0.6,blue:0.2)
        default:      return .red
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: bgColors, startPoint: .topLeading, endPoint: .bottomTrailing)

            // Decorative circles
            Circle()
                .fill(accentColor.opacity(0.06))
                .frame(width: 300)
                .offset(x: 160, y: -120)
            Circle()
                .fill(accentColor.opacity(0.04))
                .frame(width: 200)
                .offset(x: -130, y: 100)

            VStack(alignment: .leading, spacing: 0) {

                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("posturapp")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .textCase(.uppercase)
                            .tracking(2)
                        Text(report.period == .daily ? "Daily Report" : "Weekly Report")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.6))
                        Text(report.periodLabel)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    Spacer()
                    Text(report.emoji)
                        .font(.system(size: 44))
                }
                .padding(.bottom, 20)

                // Score
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("\(Int(report.score))")
                        .font(.system(size: compact ? 64 : 80, weight: .black, design: .rounded))
                        .foregroundColor(accentColor)
                    Text("%")
                        .font(.system(size: compact ? 28 : 36, weight: .bold, design: .rounded))
                        .foregroundColor(accentColor.opacity(0.7))
                        .padding(.bottom, 8)
                }

                Text(report.headline)
                    .font(.system(size: compact ? 18 : 22, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.top, -8)

                Text(report.roast)
                    .font(.system(size: compact ? 12 : 14))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)

                // Stats grid
                HStack(spacing: 12) {
                    statPill("✅ Good", value: "\(Int(report.goodMinutes))m", color: .green)
                    statPill("💀 Bad", value: "\(Int(report.badMinutes))m", color: .red)
                }
                .padding(.top, 16)

                if let issueRoast = report.issueRoast {
                    Text(issueRoast)
                        .font(.system(size: compact ? 11 : 13))
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.top, 10)
                }

                Text(report.streakComment)
                    .font(.system(size: compact ? 11 : 13))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.top, 4)

                Text(report.alertsComment)
                    .font(.system(size: compact ? 11 : 13))
                    .foregroundColor(.white.opacity(0.65))
                    .padding(.top, 4)

                Spacer()

                // Footer
                HStack {
                    Text("🦒 posturapp — sit up or else")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.3))
                    Spacer()
                    Text("github.com/lucasPellis/posturapp")
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.25))
                }
                .padding(.top, 16)
            }
            .padding(compact ? 20 : 28)
        }
        .frame(width: compact ? 320 : 480, height: compact ? 360 : 540)
        .clipShape(RoundedRectangle(cornerRadius: compact ? 16 : 24))
    }

    @ViewBuilder
    private func statPill(_ label: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: compact ? 18 : 22, weight: .black, design: .rounded))
                .foregroundColor(color)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
