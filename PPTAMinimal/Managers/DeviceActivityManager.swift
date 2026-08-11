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
    func handleRemoteLock(from coach: String) {
        let settings = LocalSettingsStore.load()
        guard settings.isTracking else { return }

        // A coach re-locking mid-grace ends the grace period outright.
        cancelUnlockGracePeriod()

        store.shield.applications = settings.applications.applicationTokens

        NotificationManager.shared.sendNotification(
            title: "Locked by \(coach)",
            body: "Your coach locked your monitored apps."
        )

        // Sync in-memory state so the main app reflects the new status immediately.
        UserSettingsManager.shared.update { $0.traineeStatus = .cutOff }

        // Best-effort: notify backend that user is now cut off.
        sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .cutOff)
    }

    @MainActor
    func handleRemoteUnlock(from coach: String) {
        let settings = LocalSettingsStore.load()

        store.shield.applications = nil

        // Only promise the countdown when tracking — in Off mode no grace is armed and
        // nothing will re-lock, so the 10-minute wording would be a lie.
        NotificationManager.shared.sendNotification(
            title: "Unlocked by \(coach)",
            body: settings.isTracking
                ? "You have \(UnlockGrace.durationMinutes) minutes in your apps before they lock again."
                : "Be Mindful of Your Screentime!"
        )

        // Sync in-memory state so the main app reflects the snooze immediately,
        // and notify coaches via the backend that the trainee is temporarily unlocked.
        if settings.isTracking {
            UserSettingsManager.shared.update { $0.traineeStatus = .snoozedLock }
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .snoozedLock)
            startUnlockGracePeriod(settings: settings)
        }
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
        guard let uid, !uid.isEmpty else { return }

        let ts = Int(Date().timeIntervalSince1970)
        let msg = "\(uid)|\(status.rawValue)|\(ts)"
        let key = SymmetricKey(data: Data(Self.sharedSecret.utf8))
        let sig = HMAC<SHA256>
            .authenticationCode(for: msg.data(using: .utf8)!, using: key)
            .map { String(format: "%02x", $0) }
            .joined()

        var req = URLRequest(url: Self.statusUpdateURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "uid": uid,
            "status": status.rawValue,
            "ts": ts,
            "sig": sig
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }
}
