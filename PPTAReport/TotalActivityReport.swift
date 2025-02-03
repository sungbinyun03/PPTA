//
//  TotalActivityReport.swift
//  PPTAReport
//
//  Created by Sungbin Yun on 1/27/25.
//
import DeviceActivity
import SwiftUI

extension DeviceActivityReport.Context {
    // If your app initializes a DeviceActivityReport with this context, then the system will use
    // your extension's corresponding DeviceActivityReportScene to render the contents of the
    // report.
    static let totalActivity = Self("Total Activity")
}

// MARK: - Device Activity Report Contents
struct TotalActivityReport: DeviceActivityReportScene {
    // Define which context your scene will represent.
    let context: DeviceActivityReport.Context = .totalActivity
    
    // Define the custom configuration and the resulting view for this report.
    let content: (ActivityReport) -> TotalActivityView
    
    /// DeviceActivityResults -> Filter
    func makeConfiguration(
        representing data: DeviceActivityResults<DeviceActivityData>) async -> ActivityReport {
        // Reformat the data into a configuration that can be used to create
        // the report's view.
        var totalActivityDuration: Double = 0
        var list: [AppDeviceActivity] = []
        
        for await eachData in data {
            for await activitySegment in eachData.activitySegments {
                for await categoryActivity in activitySegment.categories {
                    for await applicationActivity in categoryActivity.applications {
                        let appName = (applicationActivity.application.localizedDisplayName ?? "nil")
                        let bundle = (applicationActivity.application.bundleIdentifier ?? "nil")
                        let duration = applicationActivity.totalActivityDuration
                        totalActivityDuration += duration
                        let numberOfPickups = applicationActivity.numberOfPickups
                        let token = applicationActivity.application.token
                        let appActivity = AppDeviceActivity(
                            id: bundle,
                            displayName: appName,
                            duration: duration,
                            numberOfPickups: numberOfPickups,
                            token: token
                        )
                        list.append(appActivity)
                    }
                }

            }
        }
        
        return ActivityReport(totalDuration: totalActivityDuration, apps: list)
    }
}
