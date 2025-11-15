//
//  SettingsLoader.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 4/19/25.
//
import Foundation
import FamilyControls

struct SettingsLoader {
    private static let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
    private static let key   = "UserSettings"
    
    static func load() -> UserSettings {
        guard
            let data = suite?.data(forKey: key),
            let obj  = try? JSONDecoder().decode(UserSettings.self, from: data)
        else { return UserSettings() }
        return obj
    }
}
