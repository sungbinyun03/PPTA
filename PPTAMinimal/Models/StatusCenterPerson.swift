//
//  StatusCenterPerson.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

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
            lockedByName: lockedByName
        )
    }
}



