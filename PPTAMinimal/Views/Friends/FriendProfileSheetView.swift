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
    @State private var showLockNote = false
    @State private var lockNote = ""
    @State private var showSnoozeNote = false
    @State private var snoozeNote = ""
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
                    lockDelivery: vm.lockDelivery,
                    monitoredAppNames: vm.monitoredAppNames,
                    monitoredAppStats: vm.monitoredAppStats,
                    isRequestingSnoozeFromMe: vm.isRequestingSnoozeFromMe,
                    snoozeRequestMessage: vm.snoozeRequestMessage,
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
                LockNoteSheet(name: vm.name, note: $lockNote) { note in
                    lock(message: note)
                }
                .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showSnoozeNote) {
                SnoozeRequestNoteSheet(name: vm.name, note: $snoozeNote) { note in
                    vm.requestSnooze(message: note)
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
        // Signed when tapped — see `makeLockActionIfNeeded`.
        let childUID = otherUserId
        return {
            guard let url = UnlockService.makeUnlockURL(childUID: childUID, coachUID: coachUID) else { return }
            Task { await vm.performUnlock(url: url) }
        }
    }
}

/// Optional note step before a coach lock. The URL is signed by the caller when Lock is tapped.
private struct LockNoteSheet: View {
    let name: String
    @Binding var note: String
    let onLock: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Lock \(name.firstNameOnly)?")
                    .font(.custom("BambiBold", size: 22))
                    .foregroundColor(Color("primaryColor"))
                Text("They'll see your note with the lock.")
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
                    onLock(note)
                    dismiss()
                } label: {
                    Text("Lock")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.orange)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(24)
    }
}

/// Optional note step before a snooze request to a coach. Sending with no note is the same as before.
private struct SnoozeRequestNoteSheet: View {
    let name: String
    @Binding var note: String
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Ask \(name.firstNameOnly) for more time?")
                    .font(.custom("BambiBold", size: 22))
                    .foregroundColor(Color("primaryColor"))
                Text("They'll see your note with the request.")
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
                    onSend(note)
                    dismiss()
                } label: {
                    Text("Send")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TraineeStatus.snoozedLock.ringColor ?? .blue)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        .padding(24)
    }
}
