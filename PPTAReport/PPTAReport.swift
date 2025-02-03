//
//  PPTAReport.swift
//  PPTAReport
//
//  Created by Sungbin Yun on 1/27/25.
//

import DeviceActivity
import SwiftUI

@main
struct PPTAReport: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        // Create a report for each DeviceActivityReport.Context that your app supports.
        TotalActivityReport { totalActivity in
            TotalActivityView(activityReport: totalActivity)
        }
        // Add more reports here...
    }
}
