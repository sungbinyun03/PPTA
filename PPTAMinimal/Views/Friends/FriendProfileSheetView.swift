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
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack {
            if vm.name.isEmpty {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    pressureLevel: vm.pressureLevel,
                    onLock: makeLockActionIfNeeded(),
                    onUnlock: makeUnlockActionIfNeeded(),
                    lockedByName: vm.lockedByName,
                    coachAction: vm.coachAction,
                    traineeAction: vm.traineeAction,
                    onCoachPrimary: { Task { await vm.performCoachPrimary() } },
                    onCoachSecondary: { Task { await vm.performCoachSecondary() } },
                    onTraineePrimary: { Task { await vm.performTraineePrimary() } },
                    onTraineeSecondary: { Task { await vm.performTraineeSecondary() } }
                )
            }

            if let error = vm.errorMessage ?? vm.lockUnlockError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
            .overlay {
                if vm.isPerformingLockUnlock {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView()
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .task { await vm.refresh() }
        }
    }

    private func makeLockActionIfNeeded() -> (() -> Void)? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        guard vm.isTrainee else { return nil }
        guard vm.traineeStatus == .attentionNeeded else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        guard let url = UnlockService.makeLockURL(childUID: otherUserId, coachUID: coachUID) else { return nil }
        return { Task { await vm.performLock(url: url) } }
    }

    private func makeUnlockActionIfNeeded() -> (() -> Void)? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        guard vm.isTrainee else { return nil }
        guard vm.pressureLevel != .hardcore else { return nil }
        guard vm.traineeStatus == .cutOff || vm.traineeStatus == .attentionNeeded else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        guard let url = UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID) else { return nil }
        return { Task { await vm.performUnlock(url: url) } }
    }
}
