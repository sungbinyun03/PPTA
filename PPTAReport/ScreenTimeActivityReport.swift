//
//  ScreenTimeActivityReport.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/27/25.
//

import Foundation
import ManagedSettings

struct ActivityReport {
    let totalDuration: TimeInterval
    let limitMinutes: Int
    let apps: [AppDeviceActivity]
    let traineeStatus: String   // TraineeStatus raw value: "allClear", "attentionNeeded", "cutOff", "snoozedLock", "noStatus"
    let isTracking: Bool        // pressureLevel != "Off"
    let hasViableAppLimits: Bool
}

struct AppDeviceActivity: Identifiable {
    var id: String
    var displayName: String
    var duration: TimeInterval
    var numberOfPickups: Int
    var numberOfNotifications: Int
    var token: ApplicationToken?
}

struct WeeklyReport {
    let dailyBuckets: [DailyBucket]
}

struct DailyBucket: Identifiable {
    let id: Int
    let date: Date
    let duration: TimeInterval
}

// MARK: - Session scoping

/// Reduces full-day per-app usage to "usage since today's last settings change" — but **only on days
/// that had one**. On any other day the input is returned unchanged, so the ring shows the plain
/// full-day API value, which self-resets at midnight.
///
/// The app writes `ringResetAt` (a timestamp) into the App Group whenever the user saves App Limits or
/// Pressure Level (`DeviceActivityManager.markRingReset()`). If that timestamp is from **today**, the
/// first render after it snapshots each app's day usage as a baseline, and every render thereafter
/// subtracts it — so the ring rebases to 0 at the change and climbs with new usage, matching the reset
/// threshold. If `ringResetAt` is absent or from a prior day, no scoping happens.
///
/// This is deliberately decoupled from the monitoring start/stop lifecycle: relaunches and OS re-arms
/// never reset the ring, which is what caused the old "ring reads 0 after launch" bug.
enum RingSession {
    private static var suite: UserDefaults? { UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev") }
    /// Timestamp of the most recent App Limits / Pressure Level save; 0/absent when never changed.
    private static let resetKey = "ringResetAt"
    private static let baselineKey = "ringSessionBaseline"

    private struct Baseline: Codable {
        var resetAt: Double
        var dayStart: Double
        var apps: [String: TimeInterval]
    }

    /// Returns per-app durations reduced to today's post-settings-change window, or unchanged when
    /// there was no settings change today. Keyed by the same bundle id both reports use.
    static func scoped(dayApps: [String: TimeInterval], now: Date = Date()) -> [String: TimeInterval] {
        guard let suite else { return dayApps }

        let resetAt = suite.double(forKey: resetKey)
        guard resetAt > 0 else { return dayApps }   // never changed settings → full day

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now).timeIntervalSince1970
        // Only scope when the change happened *today*. A change on a prior day is irrelevant — the
        // API's own screen time already reset at midnight, so show the full day.
        guard calendar.startOfDay(for: Date(timeIntervalSince1970: resetAt)).timeIntervalSince1970 == today else {
            return dayApps
        }

        let stored: Baseline? = {
            guard let data = suite.data(forKey: baselineKey) else { return nil }
            return try? JSONDecoder().decode(Baseline.self, from: data)
        }()

        let baseline: [String: TimeInterval]
        if let stored, stored.resetAt == resetAt, stored.dayStart == today {
            baseline = stored.apps                                  // established: same change, same day
        } else {
            baseline = dayApps                                     // first render since this change → snapshot
            save(Baseline(resetAt: resetAt, dayStart: today, apps: dayApps))
        }

        var result: [String: TimeInterval] = [:]
        for (bundle, duration) in dayApps {
            result[bundle] = max(0, duration - (baseline[bundle] ?? 0))
        }
        return result
    }

    private static func save(_ baseline: Baseline) {
        guard let data = try? JSONEncoder().encode(baseline) else { return }
        suite?.set(data, forKey: baselineKey)
    }
}

extension TimeInterval {
    func toString() -> String {
        let time = NSInteger(self)
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        return String(format: "%0.2d:%0.2d", hours, minutes)
    }

    func toShortString() -> String {
        let totalMinutes = Int(self) / 60
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 { return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h" }
        return "\(mins)m"
    }
}
