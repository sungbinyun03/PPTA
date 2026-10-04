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

/// Once-per-day gating for the daily limit and warning events, as pure functions of the stored
/// marker so it can be tested without an App Group.
///
/// The daily events are armed with `includesPastActivity: true`, so they count **total** usage since
/// midnight (matching the report) and any restart of monitoring while the user is already over —
/// app launch re-arm, an App Limits re-save, a reinstall — makes them fire again at once. Without a
/// gate that re-sends the coaches' `statusUpdate`, repeats the local notification and, in Hardcore,
/// re-raises a shield a coach Released or a snooze lifted (and stamps `ShieldPolicy.lastRaisedAt`,
/// which would make a late Release look superseded).
///
/// The gate dedupes **side effects only** (coach push, local notification, status write). It must not
/// dedupe the shield itself: the marker says "the limit fired today", not "the shield is up", so a
/// shield lost for any other reason (a stop-induced `intervalDidEnd`, an app update, a cleared
/// store) would otherwise stay down until midnight. A repeat Hardcore fire therefore silently
/// re-asserts the shield (`shouldReassert`), unless a coach Release or snooze came after the last
/// raise today.
///
/// Markers live in the App Group, written by the AppMonitor extension.
/// - Limit reached: one string `day|limitMinutes|pressure`. Fires once per day for a given limit and
///   pressure level; *changing* either is a deliberate settings change and fires again if the new
///   limit is already exceeded ("save a limit below today's usage trips it right away").
/// - Warnings: one string `day|limitMinutes|highestMinutesFired`. A warning fires only if its
///   threshold is above every warning already fired for that limit today, so a burst of
///   already-passed tiers on arming delivers at most the highest one (the extension also gives all
///   warnings one notification identifier, so a lower tier that lands first is replaced).
enum LimitFireGate {
    static let reachedKey = "limitReachedFiredMarker"
    static let warningKey = "limitWarningFiredMarker"

    /// Local calendar day, e.g. `2026-09-30`.
    static func dayStamp(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// The marker to store if the limit-reached event should act now; nil if it already acted.
    static func nextReachedMarker(stored: String?, day: String, limitMinutes: Int, pressure: String) -> String? {
        let marker = "\(day)|\(limitMinutes)|\(pressure)"
        return stored == marker ? nil : marker
    }

    /// Whether a *repeat* limit-reached fire (the marker already matched) should silently put the
    /// shield back. Hardcore only: Standard never shields. Not if a coach Release/snooze happened
    /// today after the last raise (`ShieldPolicy.lastReleasedAt` vs `lastRaisedAt`) — the Release
    /// wins until something raises a new shield (a coach re-lock, snooze expiry), which stamps a
    /// later `raised`. A Release from an earlier day is ignored.
    static func shouldReassert(pressure: String, released: Date?, raised: Date?,
                               now: Date, calendar: Calendar = .current) -> Bool {
        guard pressure == PressureLevel.hardcore.rawValue else { return false }
        guard let released, calendar.isDate(released, inSameDayAs: now) else { return true }
        guard let raised else { return false }
        return raised > released
    }

    /// The marker to store if a warning at `minutes` should be delivered now; nil to drop it.
    static func nextWarningMarker(stored: String?, day: String, limitMinutes: Int, minutes: Int) -> String? {
        let parts = stored?.split(separator: "|").map(String.init) ?? []
        if parts.count == 3, parts[0] == day, parts[1] == "\(limitMinutes)",
           let highest = Int(parts[2]), minutes <= highest {
            return nil
        }
        return "\(day)|\(limitMinutes)|\(minutes)"
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

/// What a remote lock/unlock actually did on this device. Raw values are what `LockReconciler`
/// writes into `lockAck.result`, which the coach's sheet reads.
enum LockOutcome: String {
    case applied
    case notTracking
    case emptySelection
}

/// The one way this app raises and lifts a shield.
///
/// A `FamilyActivitySelection` can name individual apps, whole categories, or both, and
/// ManagedSettings keeps them on **separate** properties: `shield.applications` blocks only the
/// app tokens, and nothing in a category is touched unless `shield.applicationCategories` is set
/// too. Every shield write used to set the first and never the second — so a category-only
/// selection metered usage and fired the limit (DeviceActivity events are armed over
/// `categoryTokens` as well, see `startDeviceActivityMonitoring`), notified the coaches, and then
/// shielded nothing at all. Silent, total enforcement failure.
///
/// Both properties move together here so they cannot drift apart. That matters most on the
/// clearing side: a snooze that dropped `shield.applications` and left `applicationCategories`
/// standing would leave the trainee locked out of a whole category with no way back — worse than
/// not shielding at all.
///
/// Apps only, deliberately: the selection's `webDomainTokens` are ignored everywhere else in the
/// app too (they don't count toward viability, the limit events pass `webDomains: []`, and the UI
/// says "apps selected"), so shielding websites here would block usage that can never trigger a
/// lock.
///
/// Compiled into both the app and the AppMonitor extension (same arrangement as
/// `UnlockGrace`/`LimitEvent`), so both processes shield identically.
enum ShieldPolicy {

    /// Shields everything in `selection` — individual apps *and* whole categories.
    ///
    /// Empty sets are written as `nil` rather than as an empty policy: both mean "shield nothing",
    /// and `nil` is the value the clearing path uses, so state stays comparable.
    ///
    /// `.specific` takes an `except:` set of apps to spare inside a shielded category, left at its
    /// default empty. `FamilyActivitySelection` has no exclusion concept — a category the user
    /// picked arrives as a bare token — so there is nothing honest to put there.
    ///
    /// - Parameter recordsRaise: Stamps `lastRaisedAt`. Pass `false` for a re-assertion of a shield
    ///   that is already established (`LockReconciler`'s silent re-raise), which is not a new event
    ///   and must not make an older coach command look superseded.
    /// - Returns: `false` when it refused. An empty selection is never applied: it would write nil/nil,
    ///   which is a **clear**, so an undecodable or emptied selection would silently lift a standing
    ///   shield. The current shield is kept; use `clear` to lift one on purpose.
    @discardableResult
    static func apply(_ selection: FamilyActivitySelection, to store: ManagedSettingsStore, recordsRaise: Bool = true) -> Bool {
        let apps = selection.applicationTokens
        let categories = selection.categoryTokens
        guard !(apps.isEmpty && categories.isEmpty) else {
            print("ShieldPolicy.apply: empty selection; refusing (would clear). Keeping the current shield.")
            return false
        }
        store.shield.applications = apps.isEmpty ? nil : apps
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        if recordsRaise {
            UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?
                .set(Date().timeIntervalSince1970, forKey: lastRaisedKey)
        }
        print("Shield applied. Apps: \(apps.count), categories: \(categories.count)")
        return true
    }

    private static let lastRaisedKey = "shield.lastRaisedAt"

    /// When this process family last raised a shield for a *new* reason (coach lock, Hardcore limit,
    /// snooze running out). Lets a late "unlock" command tell that something locked the trainee
    /// after the coach released them, so it must not lift that later shield.
    static var lastRaisedAt: Date? {
        guard let t = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?
            .object(forKey: lastRaisedKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    private static let lastReleasedKey = "shield.lastReleasedAt"

    /// When a coach Release / snooze last lifted the shield on this device. Compared with
    /// `lastRaisedAt` by `LimitFireGate.shouldReassert`, so a repeat limit fire re-asserts a Hardcore
    /// shield that something else lifted, but never one a coach lifted on purpose.
    static var lastReleasedAt: Date? {
        guard let t = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?
            .object(forKey: lastReleasedKey) as? Double else { return nil }
        return Date(timeIntervalSince1970: t)
    }

    static func recordRelease() {
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?
            .set(Date().timeIntervalSince1970, forKey: lastReleasedKey)
    }

    private static let coachLockedByKey = "shield.coachLockedBy"

    /// The coach whose lock is standing on this device (first name; "" if unnamed), else nil. A
    /// durable marker of its own because `traineeStatus` / `ShieldContext.lockedByName` are wiped when
    /// pressure goes Off, which is exactly when `ShieldLift` has to tell a coach lock from a limit
    /// shield. Set by `handleRemoteLock`; dropped by `clear`, so any lift (Release, day boundary,
    /// user-initiated) ends it.
    static var coachLockedBy: String? {
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?.string(forKey: coachLockedByKey)
    }

    static func recordCoachLock(by coach: String) {
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?.set(coach, forKey: coachLockedByKey)
    }

    /// Lifts the shield completely. Clears **both** properties — see the note above on why a
    /// half-cleared shield is the worst outcome available here.
    static func clear(_ store: ManagedSettingsStore) {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")?.removeObject(forKey: coachLockedByKey)
    }
}

/// What a user-initiated Off or empty-selection save may lift. A limit-caused shield (Standard/Hardcore
/// limit, snooze-ended re-raise) goes; a standing coach lock never does, only the coach's Release ends it.
enum ShieldLift {
    enum Decision: Equatable {
        case lift
        case keepCoachLock(by: String?)  // first name, nil when unknown
    }

    /// - Parameter coachLockedBy: `ShieldPolicy.coachLockedBy`.
    static func decide(coachLockedBy: String?) -> Decision {
        guard let coachLockedBy else { return .lift }
        return .keepCoachLock(by: coachLockedBy.isEmpty ? nil : coachLockedBy)
    }
}

/// Tells the daily interval's real end from monitoring being stopped early.
///
/// `intervalDidEnd(AppUsageMonitoring)` is the day boundary's clear, but it can also arrive when
/// the app stops the activity mid-day (every cold launch, an App Limits re-save), and a Hardcore or
/// coach shield must not drop then. The interval ends at 23:59:59, so a genuine end lands in the last
/// minutes of the day. A delayed one lands after midnight, when the standing shield was raised on an
/// earlier day. Anything else is a stop. Time-based on purpose, rather than a "stopping" marker the
/// app writes before `stopMonitoring`: a marker can outlive a crashed app and then swallow the real
/// midnight clear, while the clock and the raise stamp cannot go stale.
enum DayBoundary {
    /// Local time from which an `intervalDidEnd` counts as the real interval end (interval end 23:59:59).
    static let endWindowStart = (hour: 23, minute: 58)

    static func shouldClearShieldOnIntervalEnd(now: Date, lastRaisedAt: Date?, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.hour, .minute], from: now)
        if (c.hour ?? 0) > endWindowStart.hour
            || ((c.hour ?? 0) == endWindowStart.hour && (c.minute ?? 0) >= endWindowStart.minute) {
            return true
        }
        guard let lastRaisedAt else { return true }  // pre-stamp shield: keep the old clear-at-end behavior
        return !calendar.isDate(lastRaisedAt, inSameDayAs: now)
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

    // MARK: - Ring reset marker

    /// Timestamp (`timeIntervalSince1970`) of the most recent **deliberate settings change** — an App
    /// Limits save. It only drives the `@AppStorage`/`.id()` refresh of the report views in the app so
    /// they re-query after a save. The ring itself always shows the full-day API value (self-resets at
    /// midnight); there is no "usage since reset" window.
    ///
    /// Deliberately **not** tied to the monitoring start/stop lifecycle: a cold launch briefly sees the
    /// blank default settings (`isTracking == false`) and re-arms monitoring, which must not refresh
    /// or otherwise affect the displayed usage.
    static let ringResetKey = "ringResetAt"

    /// Marks "the user just changed settings" so the report views re-query.
    /// Call from the App Limits save handler only.
    static func markRingReset() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: ringResetKey)
    }

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

        // `includesPastActivity: true` makes the threshold count TOTAL usage since midnight, the same
        // figure the report shows, instead of usage since monitoring (re)started. So a mid-day save
        // or relaunch can't reset the count, and a limit saved below today's usage trips right away.
        // The flip side — these fire immediately on any restart while over — is handled by
        // `LimitFireGate` in the extension. (The unlock grace event below deliberately does NOT
        // include past activity: it measures usage from the Release.)
        func event(atMinutes minutes: Int) -> DeviceActivityEvent {
            DeviceActivityEvent(
                applications: appTokens.applicationTokens,
                categories: appTokens.categoryTokens,
                webDomains: [],
                threshold: DateComponents(minute: minutes),
                includesPastActivity: true
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

    /// What the user turning pressure Off, or saving an empty selection, does to a standing shield:
    /// lifts a limit-caused one (stamping the release so the Hardcore re-assert gate doesn't raise it
    /// again) but never a coach lock, which stays until the coach Releases. Stopping monitoring does
    /// neither, and nothing is armed afterwards to lower the shield.
    @discardableResult
    func liftUserClearableShield() -> ShieldLift.Decision {
        let decision = ShieldLift.decide(coachLockedBy: ShieldPolicy.coachLockedBy)
        switch decision {
        case .lift:
            ShieldPolicy.recordRelease()
            ShieldPolicy.clear(store)
        case .keepCoachLock(let coach):
            NotificationManager.shared.showInAppMessage(
                title: "Coach lock stays on",
                body: "\(coach ?? "Your coach")'s lock stays on until they release it.")
        }
        return decision
    }

    /// Lifts whatever shield is up, through `ShieldPolicy` like every other clear. Stopping
    /// monitoring does not do this: a shield already raised stays up with nothing left to lower it.
    func clearShield() {
        ShieldPolicy.clear(store)
    }
    
    /// - Parameter pushShowsBanner: The incoming push already carried an APNs alert, so iOS shows
    ///   the banner itself; posting our own would be a second one for the same event.
    ///
    /// Returns once the status writes have resolved, so the caller can hold the background wake
    /// open until they have — a write left in flight when the app is suspended may not land.
    ///
    /// Returns what happened so `LockReconciler` can ack it: a lock that was not enforced
    /// (`notTracking`, `emptySelection`) must not read as applied.
    @MainActor
    @discardableResult
    func handleRemoteLock(from coach: String, coachUID: String?, pushShowsBanner: Bool = false, message: String? = nil) async -> LockOutcome {
        let settings = LocalSettingsStore.load()
        guard settings.isTracking else {
            print("handleRemoteLock: pressure is Off; not locking.")
            return .notTracking
        }
        // An empty selection would make `ShieldPolicy.apply` write nil/nil, i.e. clear the shield.
        guard !settings.applications.applicationTokens.isEmpty || !settings.applications.categoryTokens.isEmpty else {
            print("handleRemoteLock: no apps selected; not locking.")
            return .emptySelection
        }

        // A coach re-locking mid-grace ends the grace period outright.
        cancelUnlockGracePeriod()

        if ShieldPolicy.apply(settings.applications, to: store) {
            ShieldPolicy.recordCoachLock(by: coach)
        }

        if !pushShowsBanner {
            NotificationManager.shared.sendNotification(
                title: "Locked by \(coach) 🔒",
                body: ActionMessage.lockNotificationBody(message: message)
            )
        }

        // Sync in-memory state so the main app reflects the new status immediately.
        // `lockedByName` is also what the shield reads to say "Alex locked this" rather than
        // falling back to daily-limit copy. The Cloud Function writes it to Firestore, but not
        // in time for the shield that appears seconds from now, so set it locally too.
        async let saved: Void = UserSettingsManager.shared.updateAndWait {
            $0.traineeStatus = .cutOff
            $0.lockedByName = coach
        }

        // Best-effort: notify backend that user is now cut off. `cause: .coach` + the acting coach's
        // UID let the fan-out tell every coach who did it (and say "You…" to the actor).
        async let posted: Void = postToStatusUpdateAndWait(
            uid: LocalSettingsStore.loadCurrentUserId(),
            status: .cutOff,
            type: nil,
            cause: .coach,
            by: coachUID
        )
        _ = await (saved, posted)
        return .applied
    }

    /// See `handleRemoteLock` for `pushShowsBanner` and why this is awaitable.
    @MainActor
    @discardableResult
    func handleRemoteUnlock(from coach: String, coachUID: String?, pushShowsBanner: Bool = false, message: String? = nil) async -> LockOutcome {
        let settings = LocalSettingsStore.load()

        // Clearing the shield when not tracking is a harmless no-op (nothing was armed). We simply
        // don't notify or arm grace in that case: you can only be unlocked if you were locked, and
        // you can only be locked while tracking — so the not-tracking branch shouldn't really occur.
        ShieldPolicy.recordRelease()
        ShieldPolicy.clear(store)

        guard settings.isTracking else { return .notTracking }

        if !pushShowsBanner {
            NotificationManager.shared.sendNotification(
                title: "Lock snoozed by \(coach)! ⏳",
                body: ActionMessage.snoozeNotificationBody(message: message, minutes: UnlockGrace.durationMinutes)
            )
        }

        // Sync in-memory state so the main app reflects the snooze immediately, and notify all
        // coaches (including the snoozer) that this coach snoozed the lock.
        // Clear the locking coach: the shield's next appearance is a grace expiry, not this
        // coach's lock, and a stale name would misattribute it.
        // Grace is armed first, before any network wait: it is what enforces the re-lock, and
        // the write below can take seconds.
        startUnlockGracePeriod(settings: settings)
        async let saved: Void = UserSettingsManager.shared.updateAndWait {
            $0.traineeStatus = .snoozedLock
            $0.lockedByName = nil
        }
        async let posted: Void = postToStatusUpdateAndWait(
            uid: LocalSettingsStore.loadCurrentUserId(),
            status: .snoozedLock,
            type: nil,
            cause: .coach,
            by: coachUID
        )
        _ = await (saved, posted)
        return .applied
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

    /// Re-asserts an already-established coach lock with **none** of `handleRemoteLock`'s side
    /// effects — no local notification, no status write, no `statusUpdate` POST, no change to the
    /// shield context (so the coach's name on the lock screen is left as `handleRemoteLock` set it).
    /// For `LockReconciler`, whose lock is level-triggered for the day.
    ///
    /// Lives here so every app-side shield write still goes through this manager's single
    /// `ManagedSettingsStore` and through `ShieldPolicy`.
    @MainActor
    func reapplyShield(matching selection: FamilyActivitySelection) {
        ShieldPolicy.apply(selection, to: store, recordsRaise: false)
    }

    private func sendStatusUpdate(uid: String?, status: TraineeStatus) {
        postToStatusUpdate(uid: uid, status: status, type: nil)
    }

    /// Asks this user's coaches for more time, raised from the shield's secondary button.
    ///
    /// Rides the existing `statusUpdate` endpoint rather than a new service: it already
    /// resolves `coachIds` and fans out FCM. The server does **not** write any status for
    /// this type — a trainee asking is not a trainee deciding — it only notifies.
    ///
    /// - Parameter message: optional note for the coach. Cleaned here and sent as the unsigned
    ///   `message` body field, only when non-empty.
    func sendMercyRequest(uid: String?, targetCoach: String, message: String? = nil) {
        postToStatusUpdate(
            uid: uid, status: .cutOff, type: "mercyRequest", targetCoach: targetCoach,
            extra: Self.mercyRequestExtra(message: message)
        )
    }

    static func mercyRequestExtra(message: String?) -> [String: String] {
        guard let cleaned = ActionMessage.clean(message) else { return [:] }
        return ["message": cleaned]
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

    /// Reports that this user just **reinstalled** the app (their sandbox was wiped but the Keychain
    /// marker survived — see `ReinstallDetector`). Rides the `statusUpdate` fan-out like
    /// `sendMercyRequest`: the server writes no status, it only pushes `traineeReinstalled` to the
    /// trainee's coaches. The deterrent is that deleting PPTA to dodge a lock and returning is visible.
    func sendReinstallNotice(uid: String?) {
        postToStatusUpdate(uid: uid, status: .allClear, type: "reinstalled")
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
        guard let req = makeStatusUpdateRequest(
            uid: uid, status: status, type: type, cause: cause, by: by,
            targetCoach: targetCoach, extra: extra
        ) else { return }
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }

    /// `postToStatusUpdate`, returning once the request has resolved. For the push handlers, which
    /// must not let the app suspend with the POST still in flight. Failures are swallowed, same as
    /// the fire-and-forget version.
    private func postToStatusUpdateAndWait(
        uid: String?,
        status: TraineeStatus,
        type: String?,
        cause: LockCause? = nil,
        by: String? = nil
    ) async {
        guard let req = makeStatusUpdateRequest(
            uid: uid, status: status, type: type, cause: cause, by: by,
            targetCoach: nil, extra: [:]
        ) else { return }
        _ = try? await URLSession.shared.data(for: req)
    }

    private func makeStatusUpdateRequest(
        uid: String?,
        status: TraineeStatus,
        type: String?,
        cause: LockCause?,
        by: String?,
        targetCoach: String?,
        extra: [String: String]
    ) -> URLRequest? {
        guard let uid, !uid.isEmpty else { return nil }

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
        return req
    }
}
