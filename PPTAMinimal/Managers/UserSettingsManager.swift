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

        // Keep in sync with pressure level: Off means not participating in tracking.
        settings.isTracking = settings.pressureLevel.isTracking

        // Sync traineeStatus with tracking state so coaches always see an accurate ring.
        // Off → noStatus (clears any stale cutOff/attentionNeeded from a prior session).
        // Any non-Off mode → allClear (tracking just started; no limit hit yet).
        if !settings.isTracking {
            settings.traineeStatus = .noStatus
        } else if settings.traineeStatus == .noStatus {
            // Only reset to allClear from noStatus — don't overwrite an active cutOff
            // or attentionNeeded that was set by the extension mid-session.
            settings.traineeStatus = .allClear
        }
        
        // Only mirror app names to Firestore while the user has opted in; turning the toggle
        // off clears what was already uploaded rather than merely hiding it.
        settings.monitoredAppNames = settings.shareAppNamesWithCoaches
            ? Self.resolvedAppNames(for: settings)
            : []

        print("UserSettingsManager.saveSettings: will save Firestore userSettings/\(userID).")
        LocalSettingsStore.saveCurrentUserId(userID)
                
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

        Self.syncShieldContext(from: settings)

        DispatchQueue.main.async {
                   self.userSettings = settings
                   print("@@@@ User settings saved successfully")
               }
      
    }
    
    /// App names the shield extension has learned for the user's current selection.
    /// Partial by design — unlearned tokens are simply absent.
    private static func resolvedAppNames(for settings: UserSettings) -> [String] {
        var names: [String] = []
        for token in settings.applications.applicationTokens {
            if let name = AppNameStore.name(for: token) { names.append(name) }
        }
        for token in settings.applications.categoryTokens {
            if let name = AppNameStore.name(for: token) { names.append(name) }
        }
        return names.sorted()
    }

    /// Pushes newly learned names to coaches. Names accumulate in the App Group as the user
    /// hits lock screens, which can happen long after their last save, so this runs on
    /// foreground and only writes when the list actually changed.
    @MainActor
    func refreshSharedAppNamesIfNeeded() {
        let current = userSettings
        guard current.shareAppNamesWithCoaches else { return }
        let latest = Self.resolvedAppNames(for: current)
        guard latest != current.monitoredAppNames else { return }
        update { $0.monitoredAppNames = latest }
    }

    /// Mirrors the slice of state the shield extension needs into the App Group, so the lock
    /// screen can name the coach and the streak instead of showing generic copy.
    ///
    /// `lockedByName` is only passed through while the user is actually cut off — otherwise a
    /// leftover name from a previous coach lock would get attributed to a later auto-lock.
    /// Static so the escaping Firestore closures don't have to capture `self`.
    private static func syncShieldContext(from settings: UserSettings) {
        ShieldContext.save(
            ShieldContext(
                lockedByName: settings.traineeStatus == .cutOff ? settings.lockedByName : nil,
                isHardcore: settings.pressureLevel == .hardcore,
                streakStart: settings.startDailyStreakDate,
                hasCoaches: !settings.coachIds.isEmpty
            )
        )
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
                
                // Keep the app group snapshot in sync so extensions (monitor/report) always have
                // the latest selection/mode/tracking flags even if the user didn't press Save.
                LocalSettingsStore.saveCurrentUserId(userID)
                LocalSettingsStore.save(settings)
                UserSettingsManager.syncShieldContext(from: settings)

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

}


