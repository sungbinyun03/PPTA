//
//  ActionMessage.swift
//  PPTAMinimal
//
//  Optional short note a user attaches to a lock or a snooze request.
//

import Foundation

enum ActionMessage {
    /// Client cap in `Character`s (grapheme clusters), so an emoji counts as 1 and is never cut mid-sequence.
    static let maxLength = 60

    /// Trims, collapses whitespace/newlines/control characters into single spaces, and caps at
    /// `maxLength`. Returns nil when nothing is left, so "empty" and "absent" behave the same.
    static func clean(_ raw: String?) -> String? {
        guard let raw else { return nil }

        var collapsed = ""
        var lastWasSpace = true // also drops leading whitespace
        for scalar in raw.unicodeScalars {
            // Not CharacterSet.controlCharacters: it includes format chars like ZWJ, which would split emoji sequences.
            if CharacterSet.whitespacesAndNewlines.contains(scalar) || scalar.properties.generalCategory == .control {
                if !lastWasSpace { collapsed.unicodeScalars.append(" ") }
                lastWasSpace = true
            } else {
                collapsed.unicodeScalars.append(scalar)
                lastWasSpace = false
            }
        }

        let capped = String(collapsed.prefix(maxLength))
            .trimmingCharacters(in: .whitespaces) // the cut can leave a trailing space
        return capped.isEmpty ? nil : capped
    }

    /// Body of the local "Locked by ..." notification: the coach's note when there is one, else the
    /// standing hint.
    static func lockNotificationBody(message: String?) -> String {
        if let message = clean(message) { return "\u{201C}\(message)\u{201D}" }
        return "Head to a coach's profile to ask them to snooze the lock."
    }

    /// Body of the local "Lock snoozed by ..." notification: the coach's note when there is one, else
    /// the standing grace-period line.
    static func snoozeNotificationBody(message: String?, minutes: Int) -> String {
        if let message = clean(message) { return "\u{201C}\(message)\u{201D}" }
        return "You've got \(minutes) minutes before your apps lock again — make them count!"
    }

    /// Secondary line for the Home "Apps Locked" banner, or nil to keep the default copy.
    /// - Parameter coachFirstName: already reduced with `String.firstNameOnly` (not available to every
    ///   target that compiles this file).
    static func lockBannerText(coachFirstName: String, message: String?) -> String? {
        guard let message = clean(message) else { return nil }
        return "\(coachFirstName): \(message)"
    }

    /// The note a trainee attached to their snooze request to `coachUID`, read from the raw
    /// `userSettings/{trainee}` dictionary (these fields are deliberately not in the `UserSettings`
    /// Codable). Only while the coach is still in `snoozeRequestedCoachIds`, so a stale map entry
    /// never shows after the request is cleared.
    static func snoozeRequestMessage(from data: [String: Any], coachUID: String?) -> String? {
        guard let coachUID,
              let requested = data["snoozeRequestedCoachIds"] as? [String],
              requested.contains(coachUID),
              let messages = data["snoozeRequestMessages"] as? [String: Any] else { return nil }
        return clean(messages[coachUID] as? String)
    }

    /// Tooltip on the coach-side hand badge: the trainee's note as the bare message, else the standing
    /// sentence. `firstName` is already reduced with `firstNameOnly`.
    static func snoozeRequestTooltip(firstName: String, note: String?) -> String {
        if let note { return note }
        return "\(firstName) is asking for more time — open their profile to snooze their lock for 10 minutes."
    }
}
