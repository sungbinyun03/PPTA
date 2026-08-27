//
//  DeviceActivityManager.swift
//  PPTA
//
//  Created by Sungbin Yun on 12/30/24.
//

import Foundation
import ManagedSettings
import DeviceActivity
import FamilyControls
import CryptoKit

/// Identifiers and duration for the post-unlock grace period.
///
/// Compiled into both the app (which arms the grace period) and the AppMonitor
/// extension (which enforces it), so the names must live somewhere both targets see.
enum UnlockGrace {
    static let activityName = DeviceActivityName("UnlockGracePeriod")
    static let eventName = DeviceActivityEvent.Name("graceExpired")

    /// Minutes of *monitored-app usage* — not wall clock — a trainee gets after a coach
    /// releases them. The clock only runs while they're actually in the shielded apps.
    static let durationMinutes = 10
}

/// Names for the daily-limit threshold events, plus the tiered-warning logic.
///
/// The app registers these in `startDeviceActivityMonitoring`; the AppMonitor extension
/// handles them in `eventDidReachThreshold`. Both targets compile this file, so the names
/// stay in sync automatically (same arrangement as `UnlockGrace`).
///
/// Warnings are delivered as *explicit threshold events* rather than via the schedule's
/// `warningTime` callback (`eventWillReachThresholdWarning`): `warningTime` exists only on
/// `DeviceActivitySchedule`, is a single value, and fired unreliably — it cannot produce the
/// three independent warning tiers below. Explicit events fire deterministically at a set
/// amount of cumulative usage and run in the extension even when the app is force-quit.
enum LimitEvent {
    static let halfway     = DeviceActivityEvent.Name("limitHalfwayWarning")
    static let fiveMinutes = DeviceActivityEvent.Name("limitFiveMinuteWarning")
    static let twoMinutes  = DeviceActivityEvent.Name("limitTwoMinuteWarning")
    static let reached     = DeviceActivityEvent.Name("timeLimitReached")

    /// Warning thresholds (in minutes of cumulative usage) to arm for a given daily `limit`,
    /// keyed by event name. The limit-reached event is registered separately by the caller.
    ///
    /// Tiers:
    /// - `< 2`   : no warnings
    /// - `2...4` : 2-minute warning only
    /// - `5...10`: halfway + 2-minute
    /// - `> 10`  : halfway + 5-minute + 2-minute
    ///
    /// A tier is only emitted when its threshold lands in `1 ..< limit` — this keeps events off
    /// 0 minutes (which would fire instantly) and strictly before the limit itself.
    static func warningThresholds(forLimitMinutes limit: Int) -> [DeviceActivityEvent.Name: Int] {
        guard limit >= 2 else { return [:] }
        var result: [DeviceActivityEvent.Name: Int] = [:]
        func arm(_ name: DeviceActivityEvent.Name, at minutes: Int) {
            guard minutes >= 1, minutes < limit else { return }
            result[name] = minutes
        }
        arm(twoMinutes, at: limit - 2)
        if limit >= 5 { arm(halfway, at: limit / 2) }
        if limit > 10 { arm(fiveMinutes, at: limit - 5) }
        return result
    }
}

/// Why a `cutOff`/`snoozedLock` happened, sent to the backend so a coach's push can say the right
/// thing (a coach locking them vs. a Hardcore auto-lock vs. a snooze timer running out).
///
/// Single source of truth for these strings — mirrored server-side as `LOCK_CAUSE` in the
/// `statusUpdate` Cloud Function. Compiled into both the app and the AppMonitor extension (same
/// arrangement as `LimitEvent`/`UnlockGrace`), so the raw values stay in sync across processes.
enum LockCause: String {
    case hardcoreLimit   // Hardcore mode auto-locked at the daily limit (no coach involved)
    case coach           // a coach locked them (Standard) or snoozed their lock — `by` names them
    case snoozeEnded     // the post-unlock grace timer ran out and re-locked them
}

class DeviceActivityManager {
    static let shared = DeviceActivityManager()
    private init() {}
    let deviceActivityCenter = DeviceActivityCenter()
    private let store = ManagedSettingsStore()

    /// The always-on daily limit monitor. Distinct from `UnlockGrace.activityName`, which
    /// runs alongside it after a coach unlock.
    static let dailyActivityName = DeviceActivityName("AppUsageMonitoring")
    
    /// Must match backend `UNLOCK_SECRET` exactly (string bytes).
    private static let sharedSecret = "a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"
    
    /// Deployed `statusUpdate` Cloud Run URL.
    private static let statusUpdateURL = URL(string: "https://statusupdate-538124351649.us-central1.run.app")!
    
    func startDeviceActivityMonitoring(
        appTokens: FamilyActivitySelection,
        hour: Int,
        minute: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let limitMinutes = hour * 60 + minute

        // Monitor from midnight to 23:59:59, repeating daily
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        func event(atMinutes minutes: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(
                applications: appTokens.applicationTokens,
                categories: appTokens.categoryTokens,
                webDomains: [],
                threshold: DateComponents(minute: minutes)
            )
        }

        // The limit itself always fires; which warning tiers arm depends on the limit length.
        var events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [
            LimitEvent.reached: event(atMinutes: limitMinutes)
        ]
        for (name, minutes) in LimitEvent.warningThresholds(forLimitMinutes: limitMinutes) {
            events[name] = event(atMinutes: minutes)
        }

        let activityName = Self.dailyActivityName

        do {
            try deviceActivityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: events
            )
            print("Monitoring started. Activity: \(activityName.rawValue)")
            print("Schedule: \(schedule)")
            print("Limit: \(limitMinutes) min. Events: \(events.keys.map(\.rawValue).sorted())")
            print("Apps: \(appTokens.applicationTokens)")

            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Stops the daily limit monitor **only**, leaving any active unlock grace period running.
    ///
    /// Settings saves call this and then restart daily monitoring via
    /// `HomeView.startAlwaysOnMonitoring`. They must not stop the grace period too: a trainee
    /// mid-grace reads as `.allClear`, so they could otherwise open App Limits or Pressure
    /// Level, tap Save, and cancel their own re-lock.
    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring([Self.dailyActivityName])
        print("Stopped daily device activity monitoring.")
    }

    /// Stops every activity, including any unlock grace period. For teardown (sign-out,
    /// account deletion) and for dropping to pressure level Off, where nothing should stay armed.
    func stopAllMonitoring() {
        deviceActivityCenter.stopMonitoring()
        print("Stopped all device activity monitoring.")
    }
    
    @MainActor
    func handleRemoteLock(from coach: String, coachUID: String?) {
        let settings = LocalSettingsStore.load()
        guard settings.isTracking else { return }

        // A coach re-locking mid-grace ends the grace period outright.
        cancelUnlockGracePeriod()

        store.shield.applications = settings.applications.applicationTokens

        NotificationManager.shared.sendNotification(
            title: "Locked by \(coach) 🔒",
            body: "Head to a coach's profile to ask them to snooze the lock."
        )

        // Sync in-memory state so the main app reflects the new status immediately.
        // `lockedByName` is also what the shield reads to say "Alex locked this" rather than
        // falling back to daily-limit copy. The Cloud Function writes it to Firestore, but not
        // in time for the shield that appears seconds from now, so set it locally too.
        UserSettingsManager.shared.update {
            $0.traineeStatus = .cutOff
            $0.lockedByName = coach
        }

        // Best-effort: notify backend that user is now cut off. `cause: .coach` + the acting coach's
        // UID let the fan-out tell every coach who did it (and say "You…" to the actor).
        postToStatusUpdate(
            uid: LocalSettingsStore.loadCurrentUserId(),
            status: .cutOff,
            type: nil,
            cause: .coach,
            by: coachUID
        )
    }

    @MainActor
    func handleRemoteUnlock(from coach: String, coachUID: String?) {
        let settings = LocalSettingsStore.load()

        // Clearing the shield when not tracking is a harmless no-op (nothing was armed). We simply
        // don't notify or arm grace in that case: you can only be unlocked if you were locked, and
        // you can only be locked while tracking — so the not-tracking branch shouldn't really occur.
        store.shield.applications = nil

        guard settings.isTracking else { return }

        NotificationManager.shared.sendNotification(
            title: "Lock snoozed by \(coach)! ⏳",
            body: "You've got \(UnlockGrace.durationMinutes) minutes before your apps lock again — make them count!"
        )

        // Sync in-memory state so the main app reflects the snooze immediately, and notify all
        // coaches (including the snoozer) that this coach snoozed the lock.
        // Clear the locking coach: the shield's next appearance is a grace expiry, not this
        // coach's lock, and a stale name would misattribute it.
        UserSettingsManager.shared.update {
            $0.traineeStatus = .snoozedLock
            $0.lockedByName = nil
        }
        postToStatusUpdate(
            uid: LocalSettingsStore.loadCurrentUserId(),
            status: .snoozedLock,
            type: nil,
            cause: .coach,
            by: coachUID
        )
        startUnlockGracePeriod(settings: settings)
    }

    // MARK: - Unlock grace period

    /// Arms a usage-based grace window after a coach releases a trainee. Once they've spent
    /// `UnlockGrace.durationMinutes` inside the monitored apps, the extension re-shields and
    /// flips them back to `.cutOff`, putting them in front of their coaches again.
    ///
    /// Enforcement lives in the extension because it has to survive the app being force-quit.
    private func startUnlockGracePeriod(settings: UserSettings) {
        let selection = settings.applications
        guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else { return }

        // The interval must start *now*: thresholds count usage from the interval's start, so
        // a midnight-anchored interval would already be past 10 minutes and fire immediately.
        // Ending one minute "before" the start wraps the interval around midnight, giving a
        // ~24h window that always clears the minimum interval length the system enforces.
        let now = Date()
        let calendar = Calendar.current
        let schedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents([.hour, .minute], from: now),
            intervalEnd: calendar.dateComponents([.hour, .minute], from: now.addingTimeInterval(-60)),
            repeats: false
        )

        let event = DeviceActivityEvent(
            applications: selection.applicationTokens,
            categories: selection.categoryTokens,
            webDomains: [],
            threshold: DateComponents(minute: UnlockGrace.durationMinutes)
        )

        do {
            // Re-starting the same activity name overwrites the previous schedule and events,
            // so a second unlock restarts the interval and the usage count with it.
            try deviceActivityCenter.startMonitoring(
                UnlockGrace.activityName,
                during: schedule,
                events: [UnlockGrace.eventName: event]
            )
            print("Unlock grace period armed: \(UnlockGrace.durationMinutes) min of app usage.")
        } catch {
            // Failing to arm the grace period leaves the trainee unlocked for the rest of the
            // day rather than locking them out — the coach can always re-lock manually.
            print("!! Failed to arm unlock grace period:", error)
        }
    }

    /// Stops the grace window without touching the daily `AppUsageMonitoring` activity.
    func cancelUnlockGracePeriod() {
        deviceActivityCenter.stopMonitoring([UnlockGrace.activityName])
    }

    private func sendStatusUpdate(uid: String?, status: TraineeStatus) {
        postToStatusUpdate(uid: uid, status: status, type: nil)
    }

    /// Asks this user's coaches for more time, raised from the shield's secondary button.
    ///
    /// Rides the existing `statusUpdate` endpoint rather than a new service: it already
    /// resolves `coachIds` and fans out FCM. The server does **not** write any status for
    /// this type — a trainee asking is not a trainee deciding — it only notifies.
    func sendMercyRequest(uid: String?, targetCoach: String) {
        postToStatusUpdate(uid: uid, status: .cutOff, type: "mercyRequest", targetCoach: targetCoach)
    }

    /// What changed in a trainee's setup, for the coach-facing push copy.
    enum SettingsChange: String {
        case appLimits
        case pressureLevel
        case both
    }

    /// Tells this user's coaches that they changed their app limits or pressure level.
    /// Notification only — the client has already persisted the change itself.
    func sendSettingsChanged(uid: String?, change: SettingsChange) {
        postToStatusUpdate(
            uid: uid,
            status: .allClear,
            type: "settingsChanged",
            extra: ["change": change.rawValue]
        )
    }

    /// - Parameter type: `nil` for a plain status update, which keeps the original signed
    ///   message `uid|status|ts` so the server verifies older clients unchanged. A non-nil
    ///   type is appended to the signed message, so a captured signature can't be replayed
    ///   with the type swapped.
    /// - Parameters:
    ///   - type: `nil` for a plain status update, which keeps the original signed message
    ///     `uid|status|ts`. A non-nil type is appended so a captured signature can't be replayed
    ///     with the type swapped.
    ///   - cause / by: lock attribution (see `LockCause`). When present they are appended to the
    ///     signed message — order `uid|status|ts|type|cause|by`, omitting absent fields — matching
    ///     the server's reconstruction exactly. `by` is the acting coach's UID; the server resolves
    ///     the display name from it.
    private func postToStatusUpdate(
        uid: String?,
        status: TraineeStatus,
        type: String?,
        cause: LockCause? = nil,
        by: String? = nil,
        targetCoach: String? = nil,
        extra: [String: String] = [:]
    ) {
        guard let uid, !uid.isEmpty else { return }

        let ts = Int(Date().timeIntervalSince1970)
        var msg = "\(uid)|\(status.rawValue)|\(ts)"
        // Order must match the server's reconstruction: type, then targetCoach (mercy only), then
        // cause/by (status only). Absent fields are omitted on both sides.
        if let type { msg += "|\(type)" }
        if let targetCoach, !targetCoach.isEmpty { msg += "|\(targetCoach)" }
        if let cause { msg += "|\(cause.rawValue)" }
        if let by, !by.isEmpty { msg += "|\(by)" }

        let key = SymmetricKey(data: Data(Self.sharedSecret.utf8))
        let sig = HMAC<SHA256>
            .authenticationCode(for: msg.data(using: .utf8)!, using: key)
            .map { String(format: "%02x", $0) }
            .joined()

        var req = URLRequest(url: Self.statusUpdateURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var body: [String: Any] = [
            "uid": uid,
            "status": status.rawValue,
            "ts": ts,
            "sig": sig
        ]
        if let type { body["type"] = type }
        if let targetCoach, !targetCoach.isEmpty { body["targetCoach"] = targetCoach }
        if let cause { body["cause"] = cause.rawValue }
        if let by, !by.isEmpty { body["by"] = by }
        for (key, value) in extra { body[key] = value }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }
}
