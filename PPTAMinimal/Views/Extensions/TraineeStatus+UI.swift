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
        case .allClear: return .green
        case .attentionNeeded: return .red
        case .cutOff: return Color(white: 0.25) // dark gray
        case .noStatus: return nil
        }
    }
}

