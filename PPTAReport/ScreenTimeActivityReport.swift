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
    let timeLimitSeconds: TimeInterval
    let apps: [AppDeviceActivity]
}

struct AppDeviceActivity: Identifiable {
    var id: String
    var displayName: String
    var duration: TimeInterval
    var numberOfPickups: Int
    var token: ApplicationToken?
}

extension TimeInterval {
    func toString() -> String {
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
