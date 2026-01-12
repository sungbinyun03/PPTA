//
//  UserSettingsManager.swift
//  PPTAMinimal
//
//  Created by Sungbin on 6/18/24.
//
//WHERE WE TALK W FIREBASE
import Foundation
import FamilyControls
import FirebaseAuth
import Combine


final class UserSettingsManager : ObservableObject{
    static let shared = UserSettingsManager()
    private init() {}
    @Published var userSettings: UserSettings = UserSettings()
    
    private let firestoreService = FirestoreService()
    
    private var userID: String? {
        return Auth.auth().currentUser?.uid
    }

    func saveSettings(_ settings: UserSettings) {
        guard let userID = userID else {
            print("ERROR: No user is logged in. Cannot save settings.")
            return
        }
        
        print("UserSettingsManager.saveSettings: will save Firestore userSettings/\(userID). appListCount=\(settings.appList.count)")
        if !settings.appList.isEmpty {
            let sample = settings.appList.prefix(5).joined(separator: ", ")
            print("UserSettingsManager.saveSettings: appList sample: [\(sample)]")
        }
        
        firestoreService.saveUserSettings(userId: userID, settings: settings) { error in
            if let error = error {
                print("Failed to save user settings to Firestore: \(error.localizedDescription)")
            } else {
                print("User settings saved successfully for user \(userID)!")
            }
        }
        
        let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
            do {
                let data = try JSONEncoder().encode(settings)          
                suite?.set(data, forKey: "UserSettings")
            } catch {
                print("❌ Failed to encode & persist UserSettings:", error)
            }
        
        DispatchQueue.main.async {
                   self.userSettings = settings
                   print("@@@@ User settings saved successfully")
               }
      
    }
    
    func loadSettings(completion: @escaping (UserSettings) -> Void) {
        guard let userID = userID else {
            print("ERROR: No user is logged in. Cannot load settings.")
            completion(UserSettings()) // Provide default settings
            return
        }

        firestoreService.fetchUserSettings(userId: userID) { settings, error in
            if let settings = settings {
                print(userID, settings)
                completion(settings)
            } else if let error = error {
                print("Failed to load user settings from Firestore: \(error.localizedDescription)")
                completion(UserSettings()) // Return default settings if fetch fails
            }
        }
    }
    
    func loadSettingsSyncFromDefaults() -> UserSettings {
           let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
           guard let data = suite?.data(forKey: "UserSettings"),
                 let settings = try? JSONDecoder().decode(UserSettings.self, from: data)
           else { return UserSettings() }
           return settings
       }
    
    @MainActor
    func update(_ transform: (inout UserSettings) -> Void) {
        // 1. Start from the most recent in‑memory copy
        var draft = userSettings
        
        // 2. If that’s still default, fall back to persisted snapshot
        if draft.id == UserSettings().id {        // crude “isDefault” check
            draft = loadSettingsSyncFromDefaults()
        }
        
        transform(&draft)
        saveSettings(draft)
    }

    /// Reads and clears any pending trainee status / streak updates that were
    /// stored by the DeviceActivity extension in the shared defaults, then
    /// persists them to Firestore.
    @MainActor
    func applyPendingStatusIfNeeded() {
        let pending = LocalSettingsStore.consumePendingStatus()
        guard pending.status != nil || pending.resetStartDate != nil else { return }
        
        print("UserSettingsManager.applyPendingStatusIfNeeded: applying pending status or streak.")
        update { settings in
            if let status = pending.status {
                settings.traineeStatus = status
            }
            if let reset = pending.resetStartDate {
                settings.startDailyStreakDate = reset
            }
        }
    }

    /// Reads and clears any pending appList update that was produced by the DeviceActivity
    /// report extension (resolved app display names), then persists it to Firestore.
    @MainActor
    func applyPendingAppListIfNeeded() {
        print("UserSettingsManager.applyPendingAppListIfNeeded: checking for pending appList...")
        guard let apps = LocalSettingsStore.consumePendingAppList() else {
            print("UserSettingsManager.applyPendingAppListIfNeeded: none found.")
            return
        }
        guard !apps.isEmpty else {
            print("UserSettingsManager.applyPendingAppListIfNeeded: found empty list; skipping.")
            return
        }

        print("UserSettingsManager.applyPendingAppListIfNeeded: applying \(apps.count) apps.")
        print("UserSettingsManager.applyPendingAppListIfNeeded: apps sample: [\(apps.prefix(5).joined(separator: ", "))]")
        update { settings in
            settings.appList = apps
        }
    }

}


