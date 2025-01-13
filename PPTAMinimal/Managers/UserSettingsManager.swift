//
//  UserSettingsManager.swift
//  Moo-Tivation
//
//  Created by Sungbin on 6/18/24.
//

import Foundation
import FamilyControls

class UserSettingsManager {
    static let shared = UserSettingsManager()
    private init() {}
    
    private let appGroupID = "group.com.sungbinyun.com.PPTADev" 
    private var userDefaults: UserDefaults? {
        return UserDefaults(suiteName: appGroupID)
    }
    private let settingsKey = "UserSettings"
    
    func saveSettings(_ settings: UserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            userDefaults?.set(data, forKey: settingsKey)
        } catch {
            print("Failed to save user settings: \(error)")
        }
    }
    
    func loadSettings() -> UserSettings {
        guard let data = userDefaults?.data(forKey: settingsKey) else {
            return UserSettings()
        }
        
        do {
            let settings = try JSONDecoder().decode(UserSettings.self, from: data)
            return settings
        } catch {
            print("Failed to load user settings: \(error)")
            return UserSettings()
        }
    }
    
    func loadAppTokkens() -> FamilyActivitySelection {
        return loadSettings().applications
    }
    
    func loadNotificationText() -> String {
        return loadSettings().notificationText
    }
    
    func loadHoursAndMinutes() -> TimeInterval {
        let hours = loadSettings().thresholdHour
        let minutes = loadSettings().thresholdMinutes
        let totalSeconds = (hours * 3600) + (minutes * 60)
        return TimeInterval(totalSeconds)
    }
}
