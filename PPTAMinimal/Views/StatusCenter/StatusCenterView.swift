//
//  StatusCenterView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 7/10/25.
//

import SwiftUI

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
                            ForEach(vm.trainees) { user in
                                    Button(action: {
                                    selectedUserId = user.id
                                        showFriendProfile = true
                                    }) {
                                        TraineeCellView(
                                            name: user.name,
                                        status: user.traineeStatus ?? .noStatus,
                                        profilePicUrl: user.profileImageURL?.absoluteString
                                        )
                                    }
                                    .buttonStyle(.plain)
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
                            ForEach(vm.coaches) { user in
                                    Button(action: {
                                    selectedUserId = user.id
                                        showFriendProfile = true
                                    }) {
                                        CoachCellView(
                                            name: user.name,
                                        isCutOff: vm.isCurrentUserCutOff,
                                        profilePicUrl: user.profileImageURL?.absoluteString
                                        )
                                    }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .padding(.vertical)
                }
            }
            // Reserve the top safe area so content does not overlap the status bar
            .safeAreaInset(edge: .top, spacing: 0) {
                GeometryReader { geo in
                    Color.white
                        .frame(width: geo.size.width, height: geo.safeAreaInsets.top)
                        .ignoresSafeArea() // keeps the paint tidy within the inset
                }
                .frame(height: 0) // prevents GeometryReader from taking extra space
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
