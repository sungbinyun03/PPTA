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
    case snoozedLock
    case noStatus
}

