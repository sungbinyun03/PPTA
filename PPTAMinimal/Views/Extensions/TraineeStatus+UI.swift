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
        case .snoozedLock:     return Color(red: 0.2, green: 0.55, blue: 0.95) // blue — temporary grace period
        case .noStatus:        return nil
        }
    }
}

