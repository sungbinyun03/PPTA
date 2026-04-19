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
        }
        var limitMinutes = 0
        if let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev"),
           let settingsData = suite.data(forKey: "UserSettings"),
           let partial = try? JSONDecoder().decode(PartialSettings.self, from: settingsData) {
            limitMinutes = ((partial.thresholdHour ?? 0) * 60) + (partial.thresholdMinutes ?? 0)
        }

        return ActivityReport(
            totalDuration: totalDuration,
            limitMinutes: limitMinutes,
            apps: [],
            hourlyBuckets: []
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
            primary: .appPrimary(colorScheme)
        )
        .frame(maxWidth: .infinity)
    }
}
