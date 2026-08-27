//
//  StatusCenterPerson.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

// ============================================================
// ℹ️  NOTE — STILL ACTIVELY USED (not dead code)
// ============================================================
// StatusCenterPerson is the data model for TraineeCoachView
// (Home tab circles) and FriendProfileSheetView snapshots.
// It is NOT tied to the removed Status Center tab.
//
// If you ever remove TraineeCoachView, evaluate whether this
// model can be deleted or replaced with a simpler struct.
// ============================================================

import Foundation

struct StatusCenterPerson: Identifiable, Equatable {
    let id: String           // uid
    let name: String
    let profileImageURL: URL?

    // Relationship relative to current user
    let isCoach: Bool        // this person coaches current user
    let isTrainee: Bool      // this person is trainee of current user

    // Trainee-specific stats (read from that user's settings)
    let traineeStatus: TraineeStatus?
    let streakDays: Int
    let timeLimitMinutes: Int
    let pressureLevel: PressureLevel
    let lockedByName: String?

    /// True when this trainee, while cut off, has asked **the current user** (as their coach) to
    /// snooze the lock — i.e. the current user's UID is in the trainee's `snoozeRequestedCoachIds`.
    /// Precomputed by the view model. Only meaningful alongside `traineeStatus == .cutOff` — callers
    /// gate on that. Defaulted for existing sites.
    var isRequestingSnoozeFromMe: Bool = false

    /// Apps this person is monitoring, if they opted into sharing them. Defaulted so existing
    /// construction sites are unaffected; empty means "not shared" or "none learned yet".
    var monitoredAppNames: [String] = []

    /// Data this list entry already has in memory, handed to `FriendProfileSheetView`
    /// so it renders immediately instead of showing a blank loading screen.
    var profileSnapshot: FriendProfileViewModel.Snapshot {
        .init(
            name: name,
            profilePicUrl: profileImageURL?.absoluteString,
            isCoach: isCoach,
            isTrainee: isTrainee,
            traineeStatus: traineeStatus,
            streakDays: streakDays,
            timeLimitMinutes: timeLimitMinutes,
            pressureLevel: pressureLevel,
            lockedByName: lockedByName,
            isRequestingSnoozeFromMe: isRequestingSnoozeFromMe,
            monitoredAppNames: monitoredAppNames
        )
    }
}



