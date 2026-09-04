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

/// Scopes full-day per-app usage to the *current monitoring session*, so the ring shows "usage since
/// this session began" rather than the whole day. When a trainee turns pressure Off→On (or saves App
/// Limits / changes level), the enforcement threshold resets to 0; this makes the ring match.
///
/// Only the report extension can read raw Screen Time totals, so the baseline snapshot is captured and
/// subtracted here. The app stamps the session token (`monitoringSessionStartTS`) into the App Group on
/// every monitoring (re)start; the first report render of a new session snapshots each app's day usage,
/// and every render thereafter subtracts that snapshot. Because it subtracts two exact day totals (not
/// hour buckets), it's sub-minute precise — unlike a `.hourly` filter window, which snaps to the hour.
enum RingSession {
    private static var suite: UserDefaults? { UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev") }
    /// Written by the app (`DeviceActivityManager`) on each monitoring (re)start; 0/absent when Off.
    private static let tokenKey = "monitoringSessionStartTS"
    private static let baselineKey = "ringSessionBaseline"

    private struct Baseline: Codable {
        var token: Double
        var dayStart: Double
        var apps: [String: TimeInterval]
    }

    /// Returns per-app durations reduced to the current session. Keyed by the same bundle id both
    /// reports use. Returns the input unchanged when there is no active session (Off / token 0).
    static func scoped(dayApps: [String: TimeInterval], now: Date = Date()) -> [String: TimeInterval] {
        guard let suite else { return dayApps }
        let token = suite.double(forKey: tokenKey)
        guard token > 0 else { return dayApps }   // no session → don't scope

        let dayStart = Calendar.current.startOfDay(for: now).timeIntervalSince1970
        let stored: Baseline? = {
            guard let data = suite.data(forKey: baselineKey) else { return nil }
            return try? JSONDecoder().decode(Baseline.self, from: data)
        }()

        let baseline: [String: TimeInterval]
        if let stored, stored.token == token, stored.dayStart == dayStart {
            baseline = stored.apps                                   // established session, same day
        } else if let stored, stored.token == token {
            baseline = [:]                                          // same session, new day → full day
            save(Baseline(token: token, dayStart: dayStart, apps: [:]))
        } else {
            baseline = dayApps                                      // new session → snapshot now
            save(Baseline(token: token, dayStart: dayStart, apps: dayApps))
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
