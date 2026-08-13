//
//  ShieldSharedStore.swift
//  PPTAMinimal
//
//  Shared between the main app and the PPTAShieldConfiguration extension.
//
//  IMPORTANT: this file must stay free of Firebase and of `UserSettings`, which pulls in
//  FirebaseFirestore for `@DocumentID`. Shield extensions are short-lived and memory-capped;
//  linking the Firebase SDK into one risks the shield failing to draw at all. Everything
//  here is Foundation + ManagedSettings only.
//

import Foundation
import ManagedSettings

/// One definition of the App Group for everything in this file. The ID is also spelled out in
/// `LocalSettingsStore` and the entitlements; it cannot be shared with those without dragging
/// Firebase-dependent code into the shield targets.
private enum SharedDefaults {
    static var suite: UserDefaults? {
        UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
    }
}

// MARK: - Learned app names

/// Maps Screen Time tokens to real app / category names.
///
/// The main app can never resolve these itself — `Application(token:).localizedDisplayName`
/// returns nil outside privileged contexts, and `ImageRenderer` can't capture `Label(token)`.
/// The shield configuration extension *is* a privileged context, so it records each name as
/// it draws a shield and the app reads them back here.
///
/// Coverage is deliberately partial: a name is only learned once the user actually hits a
/// lock screen for that app. Callers must handle `nil`.
enum AppNameStore {
    private static var suite: UserDefaults? { SharedDefaults.suite }

    private static let namePrefix = "shield.appName."
    private static let attemptPrefix = "shield.blockAttempts."

    /// Stable cross-process key for a token.
    ///
    /// Derived from the token's `Codable` encoding — **never `hashValue`**, which Swift seeds
    /// randomly per process, so a key written by the extension would never match one computed
    /// in the app. The array wrapper keeps the payload a valid top-level JSON value no matter
    /// how `Token` chooses to encode itself.
    static func storageKey<T>(for token: Token<T>) -> String? {
        guard let data = try? JSONEncoder().encode([token]) else { return nil }
        return data.base64EncodedString()
    }

    /// Records a name. One key per token rather than a single dictionary blob, so concurrent
    /// shield processes can't clobber each other's writes.
    static func record<T>(_ token: Token<T>, name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let key = storageKey(for: token) else { return }
        suite?.set(trimmed, forKey: namePrefix + key)
    }

    static func name<T>(for token: Token<T>) -> String? {
        guard let key = storageKey(for: token) else { return nil }
        return suite?.string(forKey: namePrefix + key)
    }

    /// Counts how often the user bounced off this app while it was shielded — a craving
    /// signal DeviceActivity can't provide, since it only reports usage.
    ///
    /// Approximate: iOS does not guarantee the shield data source is re-invoked on every
    /// presentation, so treat these as a ranking, not an exact tally.
    /// How long block history is kept. Older days are dropped on write.
    static let retentionDays = 30

    /// Whole days since epoch. Coarser than a calendar date and ignores time-zone shifts,
    /// which is fine for "how many times in the last 30 days" and avoids a date formatter
    /// in a memory-capped extension.
    private static var todayIndex: Int { Int(Date().timeIntervalSince1970 / 86_400) }

    /// Counts are bucketed per day rather than kept as one running total, so a 30-day figure
    /// can expire gracefully instead of being wiped whenever a window rolls over.
    static func noteBlockAttempt<T>(for token: Token<T>) {
        guard let key = storageKey(for: token), let suite else { return }
        let bucketKey = attemptPrefix + key

        var counts = (suite.dictionary(forKey: bucketKey) as? [String: Int]) ?? [:]
        counts[String(todayIndex), default: 0] += 1

        let cutoff = todayIndex - retentionDays
        counts = counts.filter { (Int($0.key) ?? 0) > cutoff }

        suite.set(counts, forKey: bucketKey)
    }

    /// Total blocks for this token over the trailing `days`.
    static func blocks<T>(for token: Token<T>, inLastDays days: Int = retentionDays) -> Int {
        guard let key = storageKey(for: token),
              let counts = suite?.dictionary(forKey: attemptPrefix + key) as? [String: Int]
        else { return 0 }

        let cutoff = todayIndex - days
        return counts
            .filter { (Int($0.key) ?? 0) > cutoff }
            .values
            .reduce(0, +)
    }
}

// MARK: - Shield copy context

/// The small slice of user state the shield needs to write specific copy instead of
/// generic copy. Deliberately primitives: see the file header for why `UserSettings`
/// itself can't cross into the extension.
struct ShieldContext: Codable {
    /// Coach who *currently* has this user locked, else nil. The app only populates this
    /// while the status is `.cutOff`, so a stale name can't outlive the lock and get
    /// attributed to a later Hardcore auto-lock.
    var lockedByName: String?
    var isHardcore: Bool
    var streakStart: Date?

    /// Whether the user actually has coaches. Optional so payloads written before this field
    /// existed still decode. The shield only offers "Ask my coach" when this is true — a
    /// button that has nobody to contact is worse than no button.
    var hasCoaches: Bool?

    /// Mirrors `StreakCalculator.daysSince` rather than importing it, to keep the extension
    /// target dependency-free. `StreakCalculator` remains the canonical implementation.
    var streakDays: Int {
        guard let streakStart else { return 0 }
        let calendar = Calendar.current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: streakStart),
            to: calendar.startOfDay(for: Date())
        ).day ?? 0
        return max(0, days)
    }
}

// MARK: - Mercy requests

/// A trainee's "give me more time" request, raised from the shield's secondary button.
///
/// The shield action extension can't reach Firestore, so it drops a marker here and posts a
/// local notification. The main app picks it up on next foreground and actually files it.
enum MercyRequestStore {
    private static var suite: UserDefaults? { SharedDefaults.suite }

    private static let key = "shield.pendingMercyRequest"

    static func record(at date: Date = Date()) {
        suite?.set(date, forKey: key)
    }

    /// Returns the pending request's timestamp and clears it, mirroring
    /// `LocalSettingsStore.consumePendingStatus()`.
    static func consume() -> Date? {
        guard let date = suite?.object(forKey: key) as? Date else { return nil }
        suite?.removeObject(forKey: key)
        return date
    }
}

extension ShieldContext {
    private static let key = "shield.context"

    private static var suite: UserDefaults? { SharedDefaults.suite }

    static func save(_ context: ShieldContext) {
        guard let data = try? JSONEncoder().encode(context) else { return }
        suite?.set(data, forKey: key)
    }

    static func load() -> ShieldContext? {
        guard let data = suite?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(ShieldContext.self, from: data)
    }
}
