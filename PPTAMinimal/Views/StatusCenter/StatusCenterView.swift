//
//  StatusCenterView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 7/10/25.
//

// ============================================================
// ⚠️  DEAD CODE — STATUS CENTER TAB REMOVED
// ============================================================
// The Status Center was removed from the tab bar intentionally
// to keep the app focused on fewer screens.
//
// This entire file (and the other files in Views/StatusCenter/)
// are no longer reachable from the app. Safe to delete when
// ready to clean up.
//
// DO NOT add new features here or wire this back into TabNavigator.
// Use FriendProfileSheetView (via FriendsView or TraineeCoachView)
// for coach/trainee interactions instead.
// ============================================================

import SwiftUI
import FirebaseAuth

struct StatusCenterView: View {
    @StateObject private var vm = StatusCenterViewModel()
    @State private var selectedPerson: StatusCenterPerson? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 5) {
                    ProfileView(headerPart1: "", headerPart2: "Status Center", subHeader: "Your place for tracking accountability")
                    TraineeStatsRowView(trainees: vm.trainees) { trainee in
                        selectedPerson = trainee
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Trainees")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        // Trainee cells list
                        VStack(spacing: 12) {
                            if vm.trainees.isEmpty {
                                Text("No trainees yet. Add friends and request trainee roles to see them here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(vm.trainees) { user in
                                    TraineeCellView(
                                        name: user.name,
                                        status: user.traineeStatus ?? .noStatus,
                                        profilePicUrl: user.profileImageURL?.absoluteString,
                                        lockedByName: user.lockedByName,
                                        onRelease: {
                                            guard let coachUID = Auth.auth().currentUser?.uid else { return }
                                            guard let link = UnlockService.makeUnlockURL(childUID: user.id, coachUID: coachUID) else { return }
                                            Task {
                                                await vm.performAction(url: link, traineeId: user.id)
                                                // Releasing answers any open "more time" request.
                                                // Gated on success — `performAction` reports
                                                // failure via `errorMessage` — so a failed
                                                // release leaves the request outstanding.
                                                if vm.errorMessage == nil {
                                                    await MercyRequestService.resolveRequests(
                                                        traineeId: user.id,
                                                        coachId: coachUID
                                                    )
                                                }
                                            }
                                        },
                                        onLock: {
                                            guard let coachUID = Auth.auth().currentUser?.uid else { return }
                                            guard let link = UnlockService.makeLockURL(childUID: user.id, coachUID: coachUID) else { return }
                                            Task { await vm.performAction(url: link, traineeId: user.id) }
                                        }
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        HStack(alignment: .top) {
                            Text("Coaches")
                                .font(.title2)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        VStack(spacing: 12) {
                            if vm.coaches.isEmpty {
                                Text("No coaches yet. Add friends and request a coach role to see them here.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                            } else {
                                ForEach(vm.coaches) { user in
                                        Button(action: {
                                            selectedPerson = user
                                        }) {
                                            CoachCellView(
                                                name: user.name,
                                            profilePicUrl: user.profileImageURL?.absoluteString
                                            )
                                        }
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.vertical)
                }
            }
            .scrollIndicators(.hidden)
            .task { await vm.refresh() }
            .refreshable { await vm.refresh() }
            .overlay {
                if vm.isPerformingAction {
                    ZStack {
                        Color.black.opacity(0.15).ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(20)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let err = vm.errorMessage {
                    Text(err)
                        .font(.footnote)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: vm.errorMessage)
            .sheet(item: $selectedPerson, onDismiss: { Task { await vm.refresh() } }) { person in
                FriendProfileSheetView(otherUserId: person.id, snapshot: person.profileSnapshot)
            }
        }
    }
}

// Allows for preview by disabling or replacing all the required iPhone-only functionality
struct StatusCenterView_Previews: PreviewProvider {
    static var previews: some View {
        let auth = AuthViewModel()
        auth.currentUser = User(
            id: "preview-user",
            name: "Preview Name",
            email: "preview@example.com"
        )
        
        return StatusCenterView()
            .environmentObject(auth)
    }
}


// DummyProfile removed — Status Center is now backed by Firestore via `StatusCenterViewModel`.
