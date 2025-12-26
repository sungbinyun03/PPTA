//
//  LocalSettingsStore.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 5/20/25.
//

import Foundation
import FamilyControls

struct LocalSettingsStore {
    private static let suite =
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
    private static let key = "UserSettings"
    
    // Keys for cross-process status & streak updates from the extension.
    private static let pendingStatusKey = "PendingTraineeStatus"
    private static let pendingStreakKey = "PendingStreakStartDate"

    static func save(_ settings: UserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            suite?.set(data, forKey: key)
            print("LocalSettingsStore.save: persisted UserSettings to app group.")
        } catch {
            print("!! Local save failed:", error)
        }
    }

    static func load() -> UserSettings {
        guard
            let data = suite?.data(forKey: key),
            let obj  = try? JSONDecoder().decode(UserSettings.self, from: data)
        else { return UserSettings() }
        print("LocalSettingsStore.load: loaded UserSettings from app group.")
        return obj
    }
    
    /// Called from the DeviceActivity extension to record that the user is nearing
    /// or has breached their limit. The main app will later consume this and
    /// persist it to Firestore via `UserSettingsManager`.
    static func savePendingStatus(_ status: TraineeStatus, resetStartDate: Date?) {
        suite?.set(status.rawValue, forKey: pendingStatusKey)
        print("LocalSettingsStore.savePendingStatus: recorded status \(status.rawValue).")
        
        if let resetStartDate {
            suite?.set(resetStartDate, forKey: pendingStreakKey)
            print("LocalSettingsStore.savePendingStatus: recorded streak reset date \(resetStartDate).")
        } else {
            suite?.removeObject(forKey: pendingStreakKey)
        }
    }
    
    /// Returns and clears any pending trainee status / streak updates that were
    /// stored by the extension.
    static func consumePendingStatus() -> (status: TraineeStatus?, resetStartDate: Date?) {
        guard let suite else { return (nil, nil) }
        
        var status: TraineeStatus? = nil
        if let raw = suite.string(forKey: pendingStatusKey),
           let decoded = TraineeStatus(rawValue: raw) {
            status = decoded
        }
        let date = suite.object(forKey: pendingStreakKey) as? Date
        
        suite.removeObject(forKey: pendingStatusKey)
        suite.removeObject(forKey: pendingStreakKey)
        
        if let status {
            print("LocalSettingsStore.consumePendingStatus: consumed status \(status.rawValue).")
        } else {
            print("LocalSettingsStore.consumePendingStatus: no status to consume.")
        }
        if let date {
            print("LocalSettingsStore.consumePendingStatus: consumed streak reset date \(date).")
        }
        
        return (status, date)
    }
}
