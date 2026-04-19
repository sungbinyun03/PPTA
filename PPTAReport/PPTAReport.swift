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
        TotalActivityReport { totalActivity in
            TotalActivityView(activityReport: totalActivity)
        }
        WeeklyTrendReport { weeklyReport in
            WeeklyTrendView(report: weeklyReport)
        }
        SummaryRingReport { report in
            SummaryRingView(activityReport: report)
        }
    }
}
