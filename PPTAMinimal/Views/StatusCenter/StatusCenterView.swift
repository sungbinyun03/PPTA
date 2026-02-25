//
//  StatusCenterView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 7/10/25.
//

import SwiftUI
import FirebaseAuth
import UIKit

struct StatusCenterView: View {
    @StateObject private var vm = StatusCenterViewModel()
    @State private var selectedUserId: String? = nil
    @State private var showFriendProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 5) {
                    ProfileView(headerPart1: "", headerPart2: "Status Center", subHeader: "Your place for tracking accountability")
                    TraineeStatsRowView(trainees: vm.trainees) { trainee in
                        selectedUserId = trainee.id
                            showFriendProfile = true
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
                                        onRelease: {
                                            guard let coachUID = Auth.auth().currentUser?.uid else { return }
                                            guard let link = UnlockService.makeUnlockURL(childUID: user.id, coachUID: coachUID) else { return }
                                            UIApplication.shared.open(link)
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
                                        selectedUserId = user.id
                                            showFriendProfile = true
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
            .sheet(isPresented: $showFriendProfile) {
                if let otherId = selectedUserId {
                    FriendProfileSheetView(otherUserId: otherId)
                }
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
