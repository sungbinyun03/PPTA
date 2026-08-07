//
//  TraineeStatus+UI.swift
//  PPTAMinimal
//
//  UI-specific helpers for TraineeStatus kept separate from the core model.
//

import SwiftUI

extension TraineeStatus {
    var ringColor: Color? {
        switch self {
        case .allClear:        return .green
        case .attentionNeeded: return .red
        case .cutOff:          return Color(white: 0.25)
        case .snoozedLock:     return Color(red: 1.0, green: 0.7, blue: 0.0) // amber — temporarily unlocked
        case .noStatus:        return nil
        }
    }
}

