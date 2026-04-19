//
//  ScreenTimeActivityReport.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/27/25.
//

import Foundation
import ManagedSettings

struct ActivityReport {
    let totalDuration: TimeInterval
    let limitMinutes: Int
    let apps: [AppDeviceActivity]
    let hourlyBuckets: [HourlyBucket]
}

struct AppDeviceActivity: Identifiable {
    var id: String
    var displayName: String
    var duration: TimeInterval
    var numberOfPickups: Int
    var numberOfNotifications: Int
    var token: ApplicationToken?
}

struct HourlyBucket: Identifiable {
    let id: Int  // 0–23
    let duration: TimeInterval
}

struct WeeklyReport {
    let dailyBuckets: [DailyBucket]
}

struct DailyBucket: Identifiable {
    let id: Int
    let date: Date
    let duration: TimeInterval
}

extension TimeInterval {
    func toString() -> String {
        let time = NSInteger(self)
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        return String(format: "%0.2d:%0.2d", hours, minutes)
    }

    func toShortString() -> String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }
}
