//
//  WeeklyTrendReport.swift
//  PPTAReport
//

import DeviceActivity
import SwiftUI
import Foundation

extension DeviceActivityReport.Context {
    static let weeklyTrend = Self("Weekly Trend")
}

struct WeeklyTrendReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .weeklyTrend
    let content: (WeeklyReport) -> WeeklyTrendView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> WeeklyReport {
        print("WeeklyTrendReport.makeConfiguration: invoked")

        var durationByDay: [Date: TimeInterval] = [:]

        for await eachData in data {
            for await segment in eachData.activitySegments {
                let dayStart = Calendar.current.startOfDay(for: segment.dateInterval.start)
                var segmentDuration: TimeInterval = 0
                for await category in segment.categories {
                    for await app in category.applications {
                        segmentDuration += app.totalActivityDuration
                    }
                }
                durationByDay[dayStart, default: 0] += segmentDuration
            }
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let dailyBuckets = (0..<7).map { i -> DailyBucket in
            let daysAgo = 6 - i  // i=0 → oldest, i=6 → today
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            return DailyBucket(id: i, date: date, duration: durationByDay[date] ?? 0)
        }

        return WeeklyReport(dailyBuckets: dailyBuckets)
    }
}

// MARK: - Weekly Trend View

struct WeeklyTrendView: View {
    let report: WeeklyReport
    @Environment(\.colorScheme) var colorScheme

    private var primary: Color { .appPrimary(colorScheme) }

    private var maxDuration: TimeInterval {
        report.dailyBuckets.map(\.duration).max() ?? 1
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("LAST 7 DAYS")
                .font(.custom("Satoshi-Variable", size: 11))
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundColor(primary.opacity(0.6))
                .padding(.horizontal, 20)

            HStack(alignment: .bottom, spacing: 6) {
                ForEach(report.dailyBuckets) { bucket in
                    let isToday = Calendar.current.isDateInToday(bucket.date)
                    let proportion = maxDuration > 0 ? CGFloat(bucket.duration / maxDuration) : 0

                    VStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(isToday ? primary : primary.opacity(0.3))
                            .frame(height: max(proportion * 60, bucket.duration > 0 ? 4 : 2))

                        Text(dayLabel(for: bucket.date))
                            .font(.custom("Satoshi-Variable", size: 10))
                            .fontWeight(isToday ? .semibold : .regular)
                            .foregroundColor(isToday ? primary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private func dayLabel(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Now" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return String(formatter.string(from: date).prefix(1))
    }
}
