//
//  ReportAppGroupStore.swift
//  PPTAReport
//
//  Created by Assistant on 1/12/26.
//

import Foundation

/// Minimal shared app-group storage helpers for the DeviceActivityReport extension.
/// The main app consumes these values and persists them to Firestore.
enum ReportAppGroupStore {
    private static let suiteName = "group.com.sungbinyun.com.PPTADev"
    private static let pendingAppListKey = "PendingAppList"

    static func savePendingAppList(_ apps: [String]) {
        guard let suite = UserDefaults(suiteName: suiteName) else { return }
        suite.set(apps, forKey: pendingAppListKey)
        print("ReportAppGroupStore.savePendingAppList: recorded \(apps.count) apps.")
    }
}

