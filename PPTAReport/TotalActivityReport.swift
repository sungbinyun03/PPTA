//
//  TotalActivityReport.swift
//  PPTAReport
//
//  Created by Sungbin Yun on 1/27/25.
//
import DeviceActivity
import SwiftUI
import Foundation
import FamilyControls
import ManagedSettings

extension DeviceActivityReport.Context {
    static let totalActivity = Self("Total Activity")
}

struct TotalActivityReport: DeviceActivityReportScene {
    let context: DeviceActivityReport.Context = .totalActivity
    let content: (ActivityReport) -> TotalActivityView

    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>
    ) async -> ActivityReport {
        print("TotalActivityReport.makeConfiguration: invoked")

        var appData: [String: (name: String, duration: TimeInterval, pickups: Int, notifications: Int, token: ApplicationToken?)] = [:]
        var hourlyTotals = [TimeInterval](repeating: 0, count: 24)
        var totalDuration: TimeInterval = 0

        for await eachData in data {
            for await segment in eachData.activitySegments {
                let hour = Calendar.current.component(.hour, from: segment.dateInterval.start)
                guard hour < 24 else { continue }

                for await category in segment.categories {
                    for await app in category.applications {
                        let bundle = app.application.bundleIdentifier ?? "unknown-\(app.application.token?.hashValue ?? 0)"
                        let d = app.totalActivityDuration

                        if var existing = appData[bundle] {
                            existing.duration += d
                            existing.pickups += app.numberOfPickups
                            existing.notifications += app.numberOfNotifications
                            appData[bundle] = existing
                        } else {
                            appData[bundle] = (
                                app.application.localizedDisplayName ?? "",
                                d,
                                app.numberOfPickups,
                                app.numberOfNotifications,
                                app.application.token
                            )
                        }

                        hourlyTotals[hour] += d
                        totalDuration += d
                    }
                }
            }
        }

        var list = appData.map { bundle, info in
            AppDeviceActivity(
                id: bundle,
                displayName: info.name,
                duration: info.duration,
                numberOfPickups: info.pickups,
                numberOfNotifications: info.notifications,
                token: info.token
            )
        }

        // Read limit + zero-activity apps from App Group
        struct PartialSettings: Decodable {
            var applications: FamilyActivitySelection
            var thresholdHour: Int?
            var thresholdMinutes: Int?
        }

        var limitMinutes = 0

        if let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev"),
           let settingsData = suite.data(forKey: "UserSettings"),
           let partial = try? JSONDecoder().decode(PartialSettings.self, from: settingsData) {

            limitMinutes = ((partial.thresholdHour ?? 0) * 60) + (partial.thresholdMinutes ?? 0)

            let seenTokens = Set(list.compactMap { $0.token })
            for token in partial.applications.applicationTokens where !seenTokens.contains(token) {
                list.append(AppDeviceActivity(
                    id: "zero-\(token.hashValue)",
                    displayName: "",
                    duration: 0,
                    numberOfPickups: 0,
                    numberOfNotifications: 0,
                    token: token
                ))
            }
        }

        let hourlyBuckets = hourlyTotals.enumerated().map { HourlyBucket(id: $0.offset, duration: $0.element) }

        return ActivityReport(
            totalDuration: totalDuration,
            limitMinutes: limitMinutes,
            apps: list,
            hourlyBuckets: hourlyBuckets
        )
    }
}
