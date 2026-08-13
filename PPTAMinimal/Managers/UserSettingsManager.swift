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

        // Snapshot the last-persisted state before anything overwrites it. Diffing against
        // `userSettings` would not work: UserSettings is a class and callers routinely mutate
        // the shared instance before calling save, so both sides would already be equal.
        let previous = LocalSettingsStore.load()

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
        
        let stats = Self.resolvedAppStats(for: settings)
        settings.monitoredAppStats = stats
        settings.monitoredAppNames = stats.map(\.name)

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
        Self.notifyCoachesIfSetupChanged(previous: previous, settings: settings, uid: userID)

        DispatchQueue.main.async {
                   self.userSettings = settings
                   print("@@@@ User settings saved successfully")
               }
      
    }
    
    /// Notifies coaches when a trainee changes what they're being held to.
    ///
    /// Skipped on first-time setup — `previous` having no viable limits means there was
    /// nothing to change yet, and "changed their app limits" would be wrong for a trainee who
    /// just finished onboarding.
    private static func notifyCoachesIfSetupChanged(
        previous: UserSettings,
        settings: UserSettings,
        uid: String
    ) {
        guard !settings.coachIds.isEmpty, previous.hasViableAppLimits else { return }

        let limitsChanged =
            previous.thresholdHour != settings.thresholdHour ||
            previous.thresholdMinutes != settings.thresholdMinutes ||
            previous.applications.applicationTokens != settings.applications.applicationTokens ||
            previous.applications.categoryTokens != settings.applications.categoryTokens
        let pressureChanged = previous.pressureLevel != settings.pressureLevel

        guard limitsChanged || pressureChanged else { return }

        let change: DeviceActivityManager.SettingsChange =
            limitsChanged && pressureChanged ? .both : (limitsChanged ? .appLimits : .pressureLevel)
        DeviceActivityManager.shared.sendSettingsChanged(uid: uid, change: change)
    }

    /// Names + 30-day block counts for the user's current selection, from what the shield
    /// extension has learned. Partial by design — unlearned tokens are simply absent.
    /// Sorted by blocks descending so the most-hit app leads wherever this is shown.
    private static func resolvedAppStats(for settings: UserSettings) -> [MonitoredAppStat] {
        var stats: [MonitoredAppStat] = []
        for token in settings.applications.applicationTokens {
            guard let name = AppNameStore.name(for: token) else { continue }
            stats.append(MonitoredAppStat(name: name, blocks30d: AppNameStore.blocks(for: token)))
        }
        for token in settings.applications.categoryTokens {
            guard let name = AppNameStore.name(for: token) else { continue }
            stats.append(MonitoredAppStat(name: name, blocks30d: AppNameStore.blocks(for: token)))
        }
        return stats.sorted {
            $0.blocks30d == $1.blocks30d ? $0.name < $1.name : $0.blocks30d > $1.blocks30d
        }
    }

    /// Pushes newly learned names and counts to coaches. Both accumulate in the App Group as
    /// the user hits lock screens, long after their last save, so this runs on foreground and
    /// only writes when something actually changed.
    @MainActor
    func refreshSharedAppStatsIfNeeded() {
        let current = userSettings
        let latest = Self.resolvedAppStats(for: current)
        guard latest != current.monitoredAppStats else { return }
        update {
            $0.monitoredAppStats = latest
            $0.monitoredAppNames = latest.map(\.name)
        }
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


