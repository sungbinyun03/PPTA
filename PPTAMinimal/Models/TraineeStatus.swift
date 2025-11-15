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
    case noStatus
}

