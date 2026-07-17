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
        let thresholdComponents = DateComponents(hour: hour, minute: minute)
        
        // Monitor from midnight to 23:59:59, repeating daily
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true
        )

        let event = DeviceActivityEvent(
            applications: appTokens.applicationTokens,
            categories: appTokens.categoryTokens,
            webDomains: [],
            threshold: thresholdComponents
        )
        
        let activityName = Self.dailyActivityName
        let eventName = DeviceActivityEvent.Name("timeLimitReached")

        do {
            try deviceActivityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: [eventName: event]
            )
            print("Monitoring started. Activity: \(activityName.rawValue)")
            print("Schedule: \(schedule)")
            print("Event: \(eventName) => threshold \(thresholdComponents)")
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

        // Sync in-memory state so the main app reflects the new status immediately,
        // and notify the backend that the user is back to allClear.
        if settings.isTracking {
            UserSettingsManager.shared.update { $0.traineeStatus = .allClear }
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .allClear)
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
