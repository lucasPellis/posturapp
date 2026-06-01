import SwiftUI
import Charts
import AppKit

struct StatisticsView: View {

    @EnvironmentObject var statsStore: PostureStatsStore

    private var weekly: [DailyStats] { statsStore.dailyStats(forLast: 7) }
    private var hourly: [HourlyBucket] { statsStore.todayHourlyBuckets() }
    private var todayScore: Double { statsStore.todayScore() }
    private var totalBadToday: TimeInterval { statsStore.totalBadToday() }
    private var longestGood: TimeInterval { statsStore.longestGoodStreak() }

    @State private var showReport = false
    @State private var pendingReport: PostureReport? = nil
    @State private var reportImageURL: URL? = nil
    @State private var isGenerating = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // MARK: Score cards
                HStack(spacing: 16) {
                    scoreCard(
                        title: "Today's Score",
                        value: "\(Int(todayScore))%",
                        subtitle: "good posture",
                        color: scoreColor(todayScore)
                    )
                    scoreCard(
                        title: "Bad Time Today",
                        value: formatDuration(totalBadToday),
                        subtitle: "slouching/leaning",
                        color: .red
                    )
                    scoreCard(
                        title: "Best Streak",
                        value: formatDuration(longestGood),
                        subtitle: "good posture",
                        color: .green
                    )
                }

                // MARK: Today hourly breakdown
                chartSection("Today — Hourly Breakdown") {
                    if hourly.allSatisfy({ $0.goodSeconds == 0 && $0.badSeconds == 0 }) {
                        emptyState("No data yet today.\nStart monitoring to see your posture timeline.")
                    } else {
                        Chart {
                            ForEach(hourly.filter { $0.goodSeconds > 0 || $0.badSeconds > 0 }, id: \.hour) { bucket in
                                BarMark(
                                    x: .value("Hour", "\(bucket.hour):00"),
                                    y: .value("Good", bucket.goodSeconds / 60)
                                )
                                .foregroundStyle(.green.gradient)
                                .cornerRadius(3)

                                BarMark(
                                    x: .value("Hour", "\(bucket.hour):00"),
                                    y: .value("Bad", bucket.badSeconds / 60)
                                )
                                .foregroundStyle(.red.gradient)
                                .cornerRadius(3)
                            }
                        }
                        .chartYAxisLabel("Minutes")
                        .chartForegroundStyleScale(["Good": Color.green, "Bad": Color.red])
                        .frame(height: 180)
                    }
                }

                // MARK: Weekly score
                chartSection("Last 7 Days — Posture Score") {
                    if weekly.allSatisfy({ $0.score == 0 }) {
                        emptyState("No data for the past week yet.")
                    } else {
                        Chart(weekly, id: \.date) { day in
                            BarMark(
                                x: .value("Day", day.date, unit: .day),
                                y: .value("Score", day.score)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [scoreColor(day.score), scoreColor(day.score).opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(5)
                        }
                        .chartXAxis {
                            AxisMarks(values: .stride(by: .day)) { _ in
                                AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                            }
                        }
                        .chartYScale(domain: 0...100)
                        .chartYAxisLabel("Score %")
                        .frame(height: 180)
                        .chartOverlay { proxy in
                            GeometryReader { geo in
                                if let y = proxy.position(forY: 80.0) {
                                    Path { p in
                                        p.move(to: CGPoint(x: 0, y: geo.size.height - y))
                                        p.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height - y))
                                    }
                                    .stroke(Color.green.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4]))
                                }
                            }
                        }
                    }
                }

                // MARK: Bad posture reasons breakdown
                if !topReasons.isEmpty {
                    chartSection("Top Issues (Last 7 Days)") {
                        Chart(topReasons, id: \.reason) { item in
                            BarMark(
                                x: .value("Minutes", item.minutes),
                                y: .value("Reason", item.reason)
                            )
                            .foregroundStyle(.red.gradient)
                            .cornerRadius(4)
                            .annotation(position: .trailing) {
                                Text("\(Int(item.minutes))m")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(height: CGFloat(topReasons.count * 44 + 20))
                    }
                }

                // MARK: Posture Wrapped
                wrappedSection

                Spacer(minLength: 16)
            }
            .padding()
        }
        .sheet(isPresented: $showReport) {
            if let report = pendingReport {
                ReportSheet(report: report, imageURL: $reportImageURL)
            }
        }
    }

    // MARK: - Posture Wrapped

    private var wrappedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("🦒")
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Posture Wrapped")
                        .font(.system(size: 15, weight: .bold))
                    Text("Your spine's story, beautifully roasted.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 12) {
                reportButton("Daily Report", period: .daily)
                reportButton("Weekly Report", period: .weekly)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func reportButton(_ title: String, period: PostureReport.Period) -> some View {
        Button {
            generateReport(period: period)
        } label: {
            HStack(spacing: 6) {
                if isGenerating {
                    ProgressView()
                        .scaleEffect(0.7)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isGenerating)
    }

    @MainActor
    private func generateReport(period: PostureReport.Period) {
        guard !isGenerating else { return }
        isGenerating = true
        reportImageURL = nil

        let report = period == .daily
            ? PostureReport.daily(from: statsStore)
            : PostureReport.weekly(from: statsStore)

        pendingReport = report
        showReport = true

        Task { @MainActor in
            defer { isGenerating = false }
            let renderer = ImageRenderer(content: ReportCardView(report: report))
            renderer.scale = 2.0
            guard let cgImage = renderer.cgImage else { return }

            let nsImage = NSImage(cgImage: cgImage, size: NSSize(
                width: cgImage.width / 2,
                height: cgImage.height / 2
            ))

            let filename = period == .daily ? "posture_daily_report.png" : "posture_weekly_report.png"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

            guard let tiffData = nsImage.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else { return }

            try? pngData.write(to: url)
            reportImageURL = url
        }
    }

    // MARK: - Computed

    private var topReasons: [(reason: String, minutes: Double)] {
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date())!
        let badEvents = statsStore.events.filter {
            $0.type == .bad && $0.startedAt > cutoff && $0.reason != nil
        }
        var totals: [String: Double] = [:]
        for event in badEvents {
            let key = event.reason!
            totals[key, default: 0] += event.duration / 60
        }
        return totals.map { (reason: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Double) -> Color {
        if score >= 75 { return .green }
        if score >= 50 { return .orange }
        return .red
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 { return "\(Int(seconds))s" }
        if seconds < 3600 { return "\(Int(seconds / 60))m" }
        return String(format: "%.1fh", seconds / 3600)
    }

    // MARK: - View builders

    @ViewBuilder
    private func scoreCard(title: String, value: String, subtitle: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func chartSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            content()
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func emptyState(_ text: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary.opacity(0.4))
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
    }
}

// MARK: - Report Sheet

private struct ReportSheet: View {

    let report: PostureReport
    @Binding var imageURL: URL?
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Posture Wrapped")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button("Close") { dismiss() }
                    .buttonStyle(.plain)
                    .opacity(0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            Divider()

            // Report card
            ReportCardView(report: report)
                .padding(20)

            Divider()

            // Action buttons
            HStack(spacing: 12) {
                if let url = imageURL {
                    Button {
                        copyToClipboard(url: url)
                    } label: {
                        Label(copied ? "Copied!" : "Copy Image", systemImage: copied ? "checkmark" : "doc.on.clipboard")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.bordered)

                    ShareLink(item: url) {
                        Label("Share…", systemImage: "square.and.arrow.up")
                            .frame(minWidth: 130)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    ProgressView("Generating image…")
                        .progressViewStyle(.linear)
                        .frame(width: 280)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 540)
        .fixedSize(horizontal: true, vertical: true)
    }

    private func copyToClipboard(url: URL) {
        guard let image = NSImage(contentsOf: url) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects([image])
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            copied = false
        }
    }
}
