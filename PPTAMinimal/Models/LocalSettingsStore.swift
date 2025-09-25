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

    static func save(_ settings: UserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            suite?.set(data, forKey: key)
        } catch {
            print("!! Local save failed:", error)
        }
    }

    static func load() -> UserSettings {
        guard
            let data = suite?.data(forKey: key),
            let obj  = try? JSONDecoder().decode(UserSettings.self, from: data)
        else { return UserSettings() }
        return obj
    }
}
