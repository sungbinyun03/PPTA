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
    /// The note this person (my coach) sent with their lock or snooze, when the presenter knows it.
    var receivedNotes: [String] = []

    @StateObject private var vm: FriendProfileViewModel
    @State private var showUnfriendConfirm = false
    @State private var showLockNote = false
    @State private var lockNote = ""
    @State private var showSnoozeNote = false
    @State private var snoozeNote = ""
    @State private var showGrantNote = false
    @State private var grantNote = ""
    @Environment(\.dismiss) private var dismiss

    init(otherUserId: String, snapshot: FriendProfileViewModel.Snapshot = .init(), receivedNotes: [String] = []) {
        self.otherUserId = otherUserId
        self.receivedNotes = receivedNotes
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
                    lockDelivery: vm.lockDelivery,
                    monitoredAppNames: vm.monitoredAppNames,
                    monitoredAppStats: vm.monitoredAppStats,
                    isRequestingSnoozeFromMe: vm.isRequestingSnoozeFromMe,
                    snoozeRequestMessage: vm.snoozeRequestMessage,
                    receivedNotes: receivedNotes,
                    onRequestSnooze: makeRequestSnoozeActionIfNeeded(),
                    hasRequestedSnooze: vm.iHaveRequestedSnoozeFromThem,
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
            .sheet(isPresented: $showLockNote) {
                ActionNoteSheet(title: "Lock \(vm.name.firstNameOnly)?", subtitle: "They'll see your note with the lock.",
                                confirmTitle: "Lock", confirmColor: .orange, note: $lockNote) { note in
                    lock(message: note)
                }
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showSnoozeNote) {
                ActionNoteSheet(title: "Ask \(vm.name.firstNameOnly) for more time?", subtitle: "They'll see your note with the request.",
                                confirmTitle: "Send", confirmColor: TraineeStatus.snoozedLock.ringColor ?? .blue,
                                note: $snoozeNote) { note in
                    vm.requestSnooze(message: note)
                }
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showGrantNote) {
                ActionNoteSheet(title: "Snooze \(vm.name.firstNameOnly)'s lock?", subtitle: "They'll see your note with the snooze.",
                                confirmTitle: "Snooze", confirmColor: TraineeStatus.snoozedLock.ringColor ?? .blue,
                                note: $grantNote) { note in
                    unlock(message: note)
                }
                .presentationDetents([.height(280)])
            }
            .task { await vm.refresh() }
            .onAppear { vm.startWatchingLockState() }
            .onDisappear { vm.stopWatchingLockState() }
        }
    }

    private func makeLockActionIfNeeded() -> (() -> Void)? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        guard vm.isTrainee else { return nil }
        // A lock still waiting on the trainee's phone isn't offered again; a release still waiting
        // can be taken back by locking.
        guard (vm.traineeStatus == .attentionNeeded && !vm.hasPendingLock) || vm.hasPendingUnlock else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        // Signed when the sheet's Lock is tapped, not here: the signature carries a timestamp the
        // server rejects after 5 minutes, and this runs on every body evaluation, so a sheet left
        // open would send a stale one.
        return {
            lockNote = ""
            showLockNote = true
        }
    }

    private func lock(message: String) {
        guard let coachUID = Auth.auth().currentUser?.uid else { return }
        guard let url = UnlockService.makeLockURL(childUID: otherUserId, coachUID: coachUID, message: message) else { return }
        Task { await vm.performLock(url: url) }
    }

    /// Trainee side: offer "Request to snooze" only when *I* am cut off and this person is my coach.
    private func makeRequestSnoozeActionIfNeeded() -> (() -> Void)? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        guard vm.isCoach else { return nil }   // other is my coach
        guard vm.iAmCutOff else { return nil }
        return {
            snoozeNote = ""
            showSnoozeNote = true
        }
    }

    private func makeUnlockActionIfNeeded() -> (() -> Void)? {
        guard vm.friendshipStatus == .isFriend else { return nil }
        guard vm.isTrainee else { return nil }
        // Show the button for both cutOff (active) and snoozedLock (greyed-out/disabled in FriendProfileView).
        // A pending lock counts too, so a lock the phone hasn't acked can still be released.
        guard vm.traineeStatus == .cutOff || vm.traineeStatus == .snoozedLock || vm.hasPendingLock else { return nil }
        guard let coachUID = Auth.auth().currentUser?.uid else { return nil }
        // Signed when the sheet's Snooze is tapped — see `makeLockActionIfNeeded`.
        return {
            grantNote = ""
            showGrantNote = true
        }
    }

    private func unlock(message: String) {
        guard let coachUID = Auth.auth().currentUser?.uid else { return }
        guard let url = UnlockService.makeUnlockURL(childUID: otherUserId, coachUID: coachUID, message: message) else { return }
        Task { await vm.performUnlock(url: url) }
    }
}

/// Optional note step before a coach lock, a snooze, or a snooze request. Sending with no note is the
/// same as before. The caller signs the URL when the confirm button is tapped.
private struct ActionNoteSheet: View {
    let title: String
    let subtitle: String
    let confirmTitle: String
    let confirmColor: Color
    @Binding var note: String
    let onConfirm: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.custom("BambiBold", size: 22))
                    .foregroundColor(Color("primaryColor"))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            ActionMessageField(text: $note)

            HStack(spacing: 12) {
                Button { dismiss() } label: {
                    Text("Cancel")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray5))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Button {
                    onConfirm(note)
                    dismiss()
                } label: {
                    Text(confirmTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(confirmColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(24)
    }
}
