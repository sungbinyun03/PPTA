//
//  TraineeStatus.swift
//  PPTAMinimal
//
//  Central enum for trainee/coachee status usable across models and views.
//

import Foundation

public enum TraineeStatus: String, Codable, Hashable {
    case allClear
    case attentionNeeded
    case cutOff
    /// Temporarily unlocked by a coach for a 10-minute grace window; re-locks automatically when the window expires.
    /// "Snooze" is the internal name only: users see this as "Extra time" and the action as "give 10 min"
    /// (see docs/design/README.md, Terminology). Never show the word snooze in copy.
    case snoozedLock
    case noStatus
}

