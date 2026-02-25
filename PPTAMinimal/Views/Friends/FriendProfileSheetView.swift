//
//  FriendProfileSheetView.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import SwiftUI
import FirebaseAuth

struct FriendProfileSheetView: View {
    let otherUserId: String

    @StateObject private var vm: FriendProfileViewModel

    init(otherUserId: String) {
        self.otherUserId = otherUserId
        _vm = StateObject(wrappedValue: FriendProfileViewModel(otherUserId: otherUserId))
    }

    var body: some View {
        VStack {
            if vm.isLoading && vm.name.isEmpty {
                ProgressView()
                    .padding()
            } else {
                FriendProfileView(
                    name: vm.name,
                    friendshipStatus: vm.friendshipStatus,
                    isTrainee: vm.isTrainee,
                    isCoach: vm.isCoach,
                    profilePicUrl: vm.profilePicUrl,
                    traineeStatus: vm.traineeStatus,
                    streakDays: vm.streakDays,
                    timeLimitMinutes: vm.timeLimitMinutes,
                    selectedMode: vm.selectedMode,
                    unlockURL: makeUnlockURLIfNeeded(),
                    coachAction: vm.coachAction,
                    traineeAction: vm.traineeAction,
                    onCoachPrimary: { Task { await vm.performCoachPrimary() } },
                    onCoachSecondary: { Task { await vm.performCoachSecondary() } },
                    onTraineePrimary: { Task { await vm.performTraineePrimary() } },
                    onTraineeSecondary: { Task { await vm.performTraineeSecondary() } }
                )
            }

            if let error = vm.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
        .task { await vm.refresh() }
    }
    
    private func makeUnlockURLIfNeeded() -> URL? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        // vm.isTrainee means: the other user is my trainee (I coach them).
        guard vm.isTrainee else { return nil }
        guard vm.traineeStatus == .cutOff || vm.traineeStatus == .attentionNeeded else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        return UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID)
    }
}



