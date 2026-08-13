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
    @State private var showUnfriendConfirm = false
    @Environment(\.dismiss) private var dismiss

    init(otherUserId: String, snapshot: FriendProfileViewModel.Snapshot = .init()) {
        self.otherUserId = otherUserId
        _vm = StateObject(wrappedValue: FriendProfileViewModel(otherUserId: otherUserId, snapshot: snapshot))
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack {
            if vm.name.isEmpty {
                if let error = vm.errorMessage {
                    VStack(spacing: 12) {
                        Text(error)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try Again") { Task { await vm.refresh() } }
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
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
                    monitoredAppNames: vm.monitoredAppNames,
                    monitoredAppStats: vm.monitoredAppStats,
                    hasPendingMercyRequest: vm.hasPendingMercyRequest,
                    coachAction: vm.coachAction,
                    traineeAction: vm.traineeAction,
                    onCoachPrimary: { Task { await vm.performCoachPrimary() } },
                    onCoachSecondary: { Task { await vm.performCoachSecondary() } },
                    onTraineePrimary: { Task { await vm.performTraineePrimary() } },
                    onTraineeSecondary: { Task { await vm.performTraineeSecondary() } },
                    onUnfriend: { showUnfriendConfirm = true }
                )
            }

            if !vm.name.isEmpty, let error = vm.errorMessage ?? vm.lockUnlockError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.top, 8)
            }
        }
            .overlay {
                if vm.isPerformingLockUnlock || vm.isUnfriending {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView()
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .alert("Remove Friend?", isPresented: $showUnfriendConfirm) {
                Button("Remove", role: .destructive) { Task { await vm.unfriend() } }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This removes \(vm.name) as a friend and ends any coach or trainee relationship between you. You can add them again later.")
            }
            // Nothing left to display once the relationship is gone, so close the sheet.
            // FriendsView refreshes on dismiss, which drops them from the list.
            .onChange(of: vm.didUnfriend) { _, didUnfriend in
                if didUnfriend { dismiss() }
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
        // Show the button for both cutOff (active) and snoozedLock (greyed-out/disabled in FriendProfileView).
        guard vm.traineeStatus == .cutOff || vm.traineeStatus == .snoozedLock else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        guard let url = UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID) else { return nil }
        return { Task { await vm.performUnlock(url: url) } }
    }
}
