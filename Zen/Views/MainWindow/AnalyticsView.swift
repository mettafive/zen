import SwiftUI
import Charts
import SwiftData

struct DaySummary: Identifiable {
    let id = UUID()
    let date: Date
    let presentCount: Int
    let totalCount: Int

    var presenceRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(presentCount) / Double(totalCount)
    }
}

struct HourSummary: Identifiable {
    let id: Int // hour 0-23
    let hour: Int
    let presentCount: Int
    let totalCount: Int

    var presenceRate: Double {
        guard totalCount > 0 else { return 0 }
        return Double(presentCount) / Double(totalCount)
    }
}

struct AnalyticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \PresenceEntry.timestamp, order: .reverse) private var allEntries: [PresenceEntry]
    @State private var chartMode: ChartMode = .byHour

    enum ChartMode: String, CaseIterable {
        case byHour = "By Hour"
        case last7Days = "Last 7 Days"
    }

    private var todayEntries: [PresenceEntry] {
        let startOfDay = Date().startOfDay
        return allEntries.filter { $0.timestamp >= startOfDay }
    }

    private var todayPresenceRate: Double {
        guard !todayEntries.isEmpty else { return 0 }
        return Double(todayEntries.filter(\.wasPresent).count) / Double(todayEntries.count)
    }

    private var currentStreak: Int {
        var streak = 0
        for entry in allEntries {
            if entry.wasPresent { streak += 1 } else { break }
        }
        return streak
    }

    private var weekData: [DaySummary] {
        let calendar = Calendar.current
        let today = Date().startOfDay

        return (0..<7).reversed().compactMap { daysAgo in
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) else { return nil }
            let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            let dayEntries = allEntries.filter { $0.timestamp >= date && $0.timestamp < nextDate }
            return DaySummary(
                date: date,
                presentCount: dayEntries.filter(\.wasPresent).count,
                totalCount: dayEntries.count
            )
        }
    }

    private var hourData: [HourSummary] {
        let calendar = Calendar.current
        // Use last 7 days of data for hourly averages
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let recentEntries = allEntries.filter { $0.timestamp >= cutoff }

        return (0..<24).map { hour in
            let hourEntries = recentEntries.filter { calendar.component(.hour, from: $0.timestamp) == hour }
            return HourSummary(
                id: hour,
                hour: hour,
                presentCount: hourEntries.filter(\.wasPresent).count,
                totalCount: hourEntries.count
            )
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's stats
                HStack(spacing: 20) {
                    StatCard(
                        title: "Today",
                        value: "\(todayEntries.count)",
                        subtitle: "check-ins",
                        icon: "checkmark.circle"
                    )

                    StatCard(
                        title: "Presence",
                        value: todayEntries.isEmpty ? "—" : "\(Int(todayPresenceRate * 100))%",
                        subtitle: "today",
                        icon: "brain.head.profile"
                    )

                    StatCard(
                        title: "Streak",
                        value: "\(currentStreak)",
                        subtitle: "in a row",
                        icon: "flame"
                    )

                    StatCard(
                        title: "Total",
                        value: "\(allEntries.count)",
                        subtitle: "all time",
                        icon: "number"
                    )
                }

                // Chart section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Picker("", selection: $chartMode) {
                            ForEach(ChartMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 220)

                        Text(chartMode == .byHour ? "Presence by hour of day" : "Presence rate per day")
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        Spacer()
                    }

                    switch chartMode {
                    case .byHour:
                        hourlyChart
                    case .last7Days:
                        weeklyChart
                    }
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Recent entries
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Check-ins")
                        .font(.headline)

                    if allEntries.isEmpty {
                        Text("No check-ins yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(allEntries.prefix(10)) { entry in
                            HStack {
                                Image(systemName: entry.wasPresent ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundStyle(entry.wasPresent ? .green : .red)

                                Text(entry.wasPresent ? "Present" : "Not present")

                                Spacer()

                                Text(entry.timestamp, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
                                    .foregroundStyle(.secondary)
                                    .font(.system(.caption, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Hourly Chart

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hourData.allSatisfy({ $0.totalCount == 0 }) {
                Text("No data yet. Use Zen for a few days and your hourly patterns will appear here.")
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(hourData) { hour in
                    BarMark(
                        x: .value("Hour", String(format: "%02d", hour.hour)),
                        y: .value("Rate", hour.totalCount > 0 ? hour.presenceRate : 0)
                    )
                    .foregroundStyle(barColor(for: hour))
                    .cornerRadius(3)
                    .annotation(position: .top, spacing: 2) {
                        if hour.totalCount > 0 {
                            Text("\(Int(hour.presenceRate * 100))")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1.0]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel()
                            .font(.system(size: 9, design: .monospaced))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)

                // Legend
                HStack(spacing: 16) {
                    legendDot(color: .green, label: "70%+")
                    legendDot(color: .orange, label: "40-70%")
                    legendDot(color: .red, label: "<40%")
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Weekly Chart

    private var weeklyChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            if weekData.allSatisfy({ $0.totalCount == 0 }) {
                Text("No data yet. Start using Zen and your presence data will appear here.")
                    .foregroundStyle(.secondary)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
            } else {
                Chart(weekData) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("Rate", day.presenceRate)
                    )
                    .foregroundStyle(
                        day.presenceRate >= 0.7
                            ? Color.green.gradient
                            : day.presenceRate >= 0.4
                                ? Color.orange.gradient
                                : Color.red.gradient
                    )
                    .cornerRadius(4)
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.25, 0.5, 0.75, 1.0]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v * 100))%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: - Helpers

    private func barColor(for hour: HourSummary) -> AnyShapeStyle {
        guard hour.totalCount > 0 else {
            return AnyShapeStyle(Color.primary.opacity(0.08))
        }
        if hour.presenceRate >= 0.7 {
            return AnyShapeStyle(Color.green.gradient)
        } else if hour.presenceRate >= 0.4 {
            return AnyShapeStyle(Color.orange.gradient)
        } else {
            return AnyShapeStyle(Color.red.gradient)
        }
    }

    private func legendDot(color: some ShapeStyle, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
