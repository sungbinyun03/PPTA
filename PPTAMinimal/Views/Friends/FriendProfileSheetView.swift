//
//  FriendProfileSheetView.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import SwiftUI

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
                    apps: vm.apps,
                    profilePicUrl: vm.profilePicUrl,
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
}



