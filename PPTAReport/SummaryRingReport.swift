//
//  SummaryRingReport.swift
//  PPTAReport
//

import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    static let summaryRing = Self("Summary Ring")
}

struct SummaryRingReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .summaryRing
    let content: (ActivityReport) -> SummaryRingView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityReport {
        var totalDuration: TimeInterval = 0

        for await eachData in data {
            for await segment in eachData.activitySegments {
                for await category in segment.categories {
                    for await app in category.applications {
                        totalDuration += app.totalActivityDuration
                    }
                }
            }
        }

        struct PartialSettings: Decodable {
            var thresholdHour: Int?
            var thresholdMinutes: Int?
            var traineeStatus: String?
            var selectedMode: String?   // CodingKey for pressureLevel
        }
        var limitMinutes = 0
        var traineeStatus = "noStatus"
        var isTracking = false
        if let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev"),
           let settingsData = suite.data(forKey: "UserSettings"),
           let partial = try? JSONDecoder().decode(PartialSettings.self, from: settingsData) {
            limitMinutes = ((partial.thresholdHour ?? 0) * 60) + (partial.thresholdMinutes ?? 0)
            traineeStatus = partial.traineeStatus ?? "noStatus"
            isTracking = (partial.selectedMode ?? "Off") != "Off"
        }

        return ActivityReport(
            totalDuration: totalDuration,
            limitMinutes: limitMinutes,
            apps: [],
            hourlyBuckets: [],
            traineeStatus: traineeStatus,
            isTracking: isTracking
        )
    }
}

struct SummaryRingView: View {
    let activityReport: ActivityReport
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ProgressRingView(
            totalDuration: activityReport.totalDuration,
            limitMinutes: activityReport.limitMinutes,
            primary: .appPrimary(colorScheme),
            traineeStatus: activityReport.traineeStatus,
            isTracking: activityReport.isTracking
        )
        .frame(maxWidth: .infinity)
    }
}
