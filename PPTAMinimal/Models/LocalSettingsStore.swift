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
    
    // UID of the signed-in user (needed by the monitor extension for backend calls).
    private static let currentUserIdKey = "CurrentUserId"
    
    // Keys for cross-process status & streak updates from the extension.
    private static let pendingStatusKey = "PendingTraineeStatus"
    private static let pendingStreakKey = "PendingStreakStartDate"
    private static let pendingLockedByKey = "PendingLockedByName"
    private static let lastLockCommandKey = "LastAppliedLockCommandId"
    private static let lastLockCommandAtKey = "LastAppliedLockCommandAt"
    private static let lockMessageKey = "LockMessage"

    static func save(_ settings: UserSettings) {
        do {
            let data = try JSONEncoder().encode(settings)
            suite?.set(data, forKey: key)
            print("LocalSettingsStore.save: persisted UserSettings to app group.")
        } catch {
            print("!! Local save failed:", error)
        }
    }
    
    static func saveCurrentUserId(_ uid: String) {
        suite?.set(uid, forKey: currentUserIdKey)
    }
    
    static func loadCurrentUserId() -> String? {
        suite?.string(forKey: currentUserIdKey)
    }

    /// ID of the last coach lock/unlock command this device acted on (`lockCommand.id`), so the
    /// push handler and `LockReconciler` can't both apply one command.
    static var lastAppliedLockCommandId: String? {
        get { suite?.string(forKey: lastLockCommandKey) }
        set { suite?.set(newValue, forKey: lastLockCommandKey) }
    }

    /// Server time of that command (`lockCommand.at`, or the push's `at`), so the notification
    /// service extension, which can't read Firestore, can drop a push older than one already applied.
    static var lastAppliedLockCommandAt: Date? {
        get { suite?.object(forKey: lastLockCommandAtKey) as? Date }
        set { suite?.set(newValue, forKey: lastLockCommandAtKey) }
    }

    /// The coach's note on the lock standing on this device (`lockCommand.message`), else nil. Its own
    /// key, never part of `UserSettings`, so a full-document save can't write a stale copy back.
    /// Set when a lock is applied; cleared when an unlock is applied.
    static var lockMessage: String? {
        get { suite?.string(forKey: lockMessageKey) }
        set {
            if let newValue { suite?.set(newValue, forKey: lockMessageKey) }
            else { suite?.removeObject(forKey: lockMessageKey) }
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
    
    /// Called from the extensions to record a status change made while the app wasn't running. The
    /// main app will later consume this and persist it to Firestore via `UserSettingsManager`.
    ///
    /// - Parameter lockedByName: the coach whose lock this status is, for a coach lock applied by the
    ///   notification service extension. Every other status (a snooze, a limit, a snooze running out,
    ///   a new day) has no locking coach, so the default nil clears a name left from an earlier lock.
    static func savePendingStatus(_ status: TraineeStatus, resetStartDate: Date?, lockedByName: String? = nil) {
        suite?.set(status.rawValue, forKey: pendingStatusKey)
        if let lockedByName {
            suite?.set(lockedByName, forKey: pendingLockedByKey)
        } else {
            suite?.removeObject(forKey: pendingLockedByKey)
        }
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
    static func consumePendingStatus() -> (status: TraineeStatus?, resetStartDate: Date?, lockedByName: String?) {
        guard let suite else { return (nil, nil, nil) }
        
        var status: TraineeStatus? = nil
        if let raw = suite.string(forKey: pendingStatusKey),
           let decoded = TraineeStatus(rawValue: raw) {
            status = decoded
        }
        let date = suite.object(forKey: pendingStreakKey) as? Date
        let lockedByName = suite.string(forKey: pendingLockedByKey)

        suite.removeObject(forKey: pendingStatusKey)
        suite.removeObject(forKey: pendingStreakKey)
        suite.removeObject(forKey: pendingLockedByKey)
        
        if let status {
            print("LocalSettingsStore.consumePendingStatus: consumed status \(status.rawValue).")
        } else {
            print("LocalSettingsStore.consumePendingStatus: no status to consume.")
        }
        if let date {
            print("LocalSettingsStore.consumePendingStatus: consumed streak reset date \(date).")
        }
        
        return (status, date, lockedByName)
    }
}

/// Makes one process the applier of a coach command when several get it at once.
///
/// A lock/unlock push reaches the notification service extension and, if PPTA is running, the
/// app's push handler and `LockReconciler`'s listener too. `lastAppliedLockCommandId` is only
/// written once a command is done, and UserDefaults has no compare-and-set, so two processes could
/// both see "not applied" and both run it (two status POSTs, two coach notifications). The claim is
/// a file in the App Group created with `O_EXCL`, which the file system guarantees only one creator
/// wins.
///
/// A claim older than `staleAfter` is taken over: the extension can be killed mid-apply, and a
/// stuck claim must not block the command forever.
enum LockCommandClaim {
    private static let staleAfter: TimeInterval = 60

    private static var directory: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.com.sungbinyun.com.PPTADev")?
            .appendingPathComponent("LockCommandClaims", isDirectory: true)
    }

    /// True if this process now owns `id`. Fails open (true) when the App Group is unavailable,
    /// which matches the behaviour before claims existed.
    static func tryClaim(_ id: String) -> Bool {
        guard let dir = directory else { return true }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(id).path
        for _ in 0..<2 {
            let fd = open(path, O_CREAT | O_EXCL | O_WRONLY, 0o644)
            if fd >= 0 {
                close(fd)
                pruneOld(in: dir)
                return true
            }
            guard errno == EEXIST else { return true }
            let created = (try? FileManager.default.attributesOfItem(atPath: path))?[.creationDate] as? Date
            guard let created, Date().timeIntervalSince(created) > staleAfter else { return false }
            try? FileManager.default.removeItem(atPath: path)
        }
        return false
    }

    /// Gives up a claim on a command that was not enforced (a lock while pressure is Off), so a
    /// later reconcile can retry it.
    static func release(_ id: String) {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(at: dir.appendingPathComponent(id))
    }

    /// Claims only matter for seconds; drop anything older than a day.
    private static func pruneOld(in dir: URL) {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: dir, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for file in files {
            let created = (try? file.resourceValues(forKeys: [.creationDateKey]))?.creationDate
            if let created, Date().timeIntervalSince(created) > 86_400 {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}
