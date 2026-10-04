//
//  CoachActionDisplay.swift
//  PPTAMinimal
//
//  What the trainee's coach row shows per coach: a lock badge, a snooze halo, and the coach's lock
//  note. Pure: it turns the raw `userSettings/{me}` dictionary into display state, and never writes.
//

import Foundation

/// Phone copy of the last coach lock note, for an old server whose unlock overwrites `lockCommand`
/// (a new server carries it as `lockCommand.lockNote`). `UserDefaults.standard` only, keyed by the
/// user, and never Codable into `UserSettings` or the App Group: a copy the shield could read could
/// put a stale note on it.
struct LockNoteCache: Codable, Equatable {
    var uid: String
    var lockId: String
    var by: String
    var byName: String
    var message: String
    var at: Date

    private static let keyPrefix = "LockNoteCache."

    static func load(uid: String, defaults: UserDefaults = .standard) -> LockNoteCache? {
        guard let data = defaults.data(forKey: keyPrefix + uid) else { return nil }
        return try? JSONDecoder().decode(LockNoteCache.self, from: data)
    }

    static func save(_ cache: LockNoteCache?, uid: String, defaults: UserDefaults = .standard) {
        guard let cache, let data = try? JSONEncoder().encode(cache) else {
            defaults.removeObject(forKey: keyPrefix + uid)
            return
        }
        defaults.set(data, forKey: keyPrefix + uid)
    }
}

struct CoachActionDisplay: Equatable {
    enum Lock: Equatable {
        /// Red badge: this coach locked my apps.
        case active
        /// Grey badge: this coach's lock was snoozed; the badge still carries their note.
        case snoozed
    }

    var lock: Lock?
    /// This coach snoozed my lock.
    var halo = false
    /// A RECEIVED note only: the coach's lock note. Never the user's own snooze-request note.
    var lockNote: String?
    /// Id of the lock command behind an active badge; keys the default-open tooltip so a new lock reopens it.
    var lockId: String?
    /// Full name of the coach who snoozed, for the grey badge's tooltip.
    var snoozedByName: String?

    enum CacheUpdate: Equatable {
        case keep
        case clear
        case set(LockNoteCache)
    }

    // MARK: - Derivation

    /// Per-coach display state, keyed by coach UID. Empty when there is no coach lock or snooze to show.
    static func derive(from data: [String: Any], uid: String, cache: LockNoteCache?, now: Date,
                       calendar: Calendar = .current) -> [String: CoachActionDisplay] {
        let status = TraineeStatus(rawValue: data["traineeStatus"] as? String ?? "") ?? .noStatus
        let lockedBy = (data["lockedByUID"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let command = LockReconciler.Command(data["lockCommand"])
        var result: [String: CoachActionDisplay] = [:]

        // A coach lock: cutOff plus the coach who caused it. A Hardcore auto-lock has no `lockedByUID`.
        if status == .cutOff, let lockedBy {
            var entry = CoachActionDisplay(lock: .active)
            if let command, command.action == .lock, command.by == lockedBy {
                entry.lockNote = command.message
                entry.lockId = command.id
            }
            result[lockedBy] = entry
            return result
        }

        // A snooze: running, or ended and the apps re-locked on their own. Only an unlock command
        // from today backs the ended case, so yesterday's snooze can't decorate today's auto-lock.
        let snoozeEnded = status == .cutOff && command?.action == .unlock
            && command?.at.map { calendar.isDate($0, inSameDayAs: now) } ?? true
        guard status == .snoozedLock || snoozeEnded else { return result }

        var note: (by: String, message: String)?
        if let command, command.action == .unlock {
            if let snoozer = command.by, !snoozer.isEmpty {
                result[snoozer, default: CoachActionDisplay()].halo = true
            }
            if let raw = (data["lockCommand"] as? [String: Any])?["lockNote"] as? [String: Any],
               let by = raw["by"] as? String, !by.isEmpty,
               let message = ActionMessage.clean(raw["message"] as? String) {
                note = (by, message)
            }
        }
        if note == nil, let cache, cache.uid == uid, !cache.by.isEmpty,
           calendar.isDate(cache.at, inSameDayAs: now),
           let message = ActionMessage.clean(cache.message) {
            note = (cache.by, message)
        }
        if let note {
            result[note.by, default: CoachActionDisplay()].lock = .snoozed
            result[note.by]?.lockNote = note.message
            if let command, command.action == .unlock { result[note.by]?.snoozedByName = command.byName }
        }
        return result
    }

    /// What the phone cache should do after this snapshot: remember a lock note, drop it once the
    /// episode is over, or leave it alone (a snooze is when it is needed).
    static func cacheUpdate(from data: [String: Any], uid: String, now: Date) -> CacheUpdate {
        let status = TraineeStatus(rawValue: data["traineeStatus"] as? String ?? "") ?? .noStatus
        switch status {
        case .allClear, .noStatus, .attentionNeeded:
            return .clear
        case .snoozedLock:
            return .keep
        case .cutOff:
            guard let lockedBy = (data["lockedByUID"] as? String).flatMap({ $0.isEmpty ? nil : $0 }),
                  let command = LockReconciler.Command(data["lockCommand"]),
                  command.action == .lock, command.by == lockedBy else { return .keep }
            // A note-less lock is a new lock too: drop the previous coach's note rather than let it
            // resurface as the grey badge during this lock's snooze.
            guard let message = command.message else { return .clear }
            return .set(LockNoteCache(uid: uid, lockId: command.id, by: lockedBy,
                                      byName: command.byName ?? "", message: message, at: command.at ?? now))
        }
    }

    // MARK: - Copy

    /// Tooltip text behind the lock badge, or nil when there is no badge. A note shows as the bare
    /// message (no prefix, no quotes); without one, the fallback sentence. `coachFirstName` is already
    /// reduced with `firstNameOnly`.
    func tooltip(coachFirstName: String) -> String? {
        switch lock {
        case .active:
            if let lockNote { return lockNote }
            return "\(coachFirstName) locked your apps. Open their profile to ask for a snooze."
        case .snoozed:
            return lockNote
        case nil:
            return nil
        }
    }
}

/// Which note tooltip opens by itself on Home. Pure bookkeeping over opaque keys (a lock id, or a
/// trainee id plus request note); the views own the state. A dismissed key stays closed until it
/// leaves the candidates, so a NEW lock or request (new key) opens again.
enum TooltipDefaultOpen {
    /// Arrival order with keys that are gone dropped and new ones appended (in `candidates` order).
    /// Requests carry no timestamp, so first-seen order is the best "most recent" available.
    static func updatedArrival(_ arrival: [String], candidates: [String]) -> [String] {
        arrival.filter(candidates.contains) + candidates.filter { !arrival.contains($0) }
    }

    /// The most recently arrived candidate, or nil when it was dismissed. Older candidates never
    /// take over once the latest is dismissed.
    static func pick(candidates: [String], arrival: [String], dismissed: Set<String>) -> String? {
        let latest = candidates.max { (arrival.firstIndex(of: $0) ?? -1) < (arrival.firstIndex(of: $1) ?? -1) }
        guard let latest, !dismissed.contains(latest) else { return nil }
        return latest
    }
}
