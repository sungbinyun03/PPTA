//
//  StatusCenterView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 7/10/25.
//

import SwiftUI

struct StatusCenterView: View {
    // Index lists that reference dummyUsers array
    private var dummyTraineeIdxList: [Int] = [0, 1, 3, 4]
    private var dummyCoachIdxList: [Int] = [2, 4]
    
    // State for showing friend profile modal
    @State private var selectedProfile: SelectedProfile? = nil
    @State private var showFriendProfile = false
    
    // Helper struct to pass profile data to modal
    private struct SelectedProfile {
        let name: String
        let isTrainee: Bool
        let isCoach: Bool
        let apps: [String]
        let profilePicUrl: String?
    }
    
    // Helper to determine if a user at index is a trainee
    private func isTrainee(at index: Int) -> Bool {
        return dummyTraineeIdxList.contains(index)
    }
    
    // Helper to determine if a user at index is a coach
    private func isCoach(at index: Int) -> Bool {
        return dummyCoachIdxList.contains(index)
    }
    
    private var filteredDummyTrainees: [DummyProfile] { // TODO: remove once we feed in the actual values and info (viewModel)
        dummyTraineeIdxList.compactMap { idx in
            guard idx >= 0 && idx < dummyUsers.count else { return nil }
            return dummyUsers[idx]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 5) {
                    ProfileView(headerPart1: "", headerPart2: "Status Center", subHeader: "Your place for tracking accountability")
                    TraineeStatsRowView(trainees: filteredDummyTrainees) { trainee in
                        // Find the index of this trainee in dummyUsers
                        if let index = dummyUsers.firstIndex(where: { $0.name == trainee.name }) {
                            selectedProfile = SelectedProfile(
                                name: trainee.name,
                                isTrainee: isTrainee(at: index),
                                isCoach: isCoach(at: index),
                                apps: trainee.monitoredApps,
                                profilePicUrl: nil
                            )
                            showFriendProfile = true
                        }
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
                            ForEach(dummyTraineeIdxList, id: \.self) { idx in
                                if idx >= 0 && idx < dummyUsers.count {
                                    let user = dummyUsers[idx]
                                    Button(action: {
                                        selectedProfile = SelectedProfile(
                                            name: user.name,
                                            isTrainee: isTrainee(at: idx),
                                            isCoach: isCoach(at: idx),
                                            apps: user.monitoredApps,
                                            profilePicUrl: nil
                                        )
                                        showFriendProfile = true
                                    }) {
                                        TraineeCellView(
                                            name: user.name,
                                            status: user.status,
                                            profilePicUrl: nil
                                        )
                                    }
                                    .buttonStyle(.plain)
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
                            ForEach(dummyCoachIdxList, id: \.self) { idx in
                                if idx >= 0 && idx < dummyUsers.count {
                                    let user = dummyUsers[idx]
                                    Button(action: {
                                        selectedProfile = SelectedProfile(
                                            name: user.name,
                                            isTrainee: isTrainee(at: idx),
                                            isCoach: isCoach(at: idx),
                                            apps: user.monitoredApps,
                                            profilePicUrl: nil
                                        )
                                        showFriendProfile = true
                                    }) {
                                        CoachCellView(
                                            name: user.name,
                                            isCutOff: true, // TODO: Wire it up to the current User's status
                                            profilePicUrl: nil
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
            .sheet(isPresented: $showFriendProfile) {
                if let profile = selectedProfile {
                    FriendProfileView(
                        name: profile.name,
                        friendshipStatus: .isFriend, // All users in StatusCenter are friends
                        isTrainee: profile.isTrainee,
                        isCoach: profile.isCoach,
                        apps: profile.apps,
                        profilePicUrl: profile.profilePicUrl
                    )
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


struct DummyProfile: Identifiable {
  let id = UUID()
  let name: String
  let username: String
  let role: Role
  let streakDays: Int
  let status: TraineeStatus
  let monitoredApps: [String]    // up to 5
  let timeLimitMinutes: Int      // shared limit across monitored apps

      enum Role { case trainee, coach }

      var initials: String {
          let parts = name.split(separator: " ")
          let first = parts.first?.first.map(String.init) ?? ""
          let last =
  parts.dropFirst().first?.first.map(String.init) ?? ""
          return (first + last).uppercased()
      }

  }

  // Helpers for sample data
  private func limitApps(_ apps: [String]) -> [String] {
  Array(apps.prefix(5))
  }

  // Sample apps pool (pick a few per user)
  private let sampleApps = [
  "TikTok", "YouTube", "Instagram", "Snapchat", "Reddit",
  "X", "Twitch", "Discord", "Safari", "Roblox"
  ]

  // Combined sample data - all users in one array
  // Use dummyTraineeIdxList and dummyCoachIdxList to determine which users appear in each section
  private let dummyUsers: [DummyProfile] = [
  // Index 0 - Trainee
  .init(
  name: "Peter Parker",
  username: "spidey",
  role: .trainee,
  streakDays: 6,
  status: .allClear,
  monitoredApps: limitApps(["TikTok", "Instagram", "YouTube"]),
  timeLimitMinutes: 90
  ),
  // Index 1 - Trainee
  .init(
  name: "Shuri Wakanda",
  username: "princessshuri",
  role: .trainee,
  streakDays: 12,
  status: .attentionNeeded,
  monitoredApps: limitApps(["YouTube", "Reddit", "Safari",
  "Discord"]),
  timeLimitMinutes: 120
  ),
  // Index 2 - Coach (also appears in coaches list)
  .init(
  name: "Kamala Khan",
  username: "msmarvel",
  role: .trainee,
  streakDays: 3,
  status: .attentionNeeded,
  monitoredApps: limitApps(["TikTok", "Snapchat", "Instagram"]),
  timeLimitMinutes: 60
  ),
  // Index 3 - Trainee
  .init(
  name: "Kate Bishop",
  username: "hawkeye2",
  role: .trainee,
  streakDays: 21,
  status: .cutOff,
  monitoredApps: limitApps(["Instagram", "X", "YouTube", "Discord",
  "Safari"]),
  timeLimitMinutes: 75
  ),
  // Index 4 - Coach (also appears in trainees list, so this person is both)
  .init(
  name: "Tony Stark",
  username: "ironman",
  role: .coach,
  streakDays: 45,
  status: .allClear,
  monitoredApps: limitApps(["X", "YouTube", "Discord"]),
  timeLimitMinutes: 120
  ),
  // Index 5 - Coach
  .init(
  name: "Steve Rogers",
  username: "cap",
  role: .coach,
  streakDays: 30,
  status: .allClear,
  monitoredApps: limitApps(["Reddit", "Safari"]),
  timeLimitMinutes: 90
  ),
  // Index 6 - Coach
  .init(
  name: "Natasha Romanoff",
  username: "blackwidow",
  role: .coach,
  streakDays: 18,
  status: .attentionNeeded,
  monitoredApps: limitApps(["Instagram", "TikTok"]),
  timeLimitMinutes: 60
  ),
  // Index 7 - Coach
  .init(
  name: "Bruce Banner",
  username: "hulk",
  role: .coach,
  streakDays: 2,
  status: .cutOff,
  monitoredApps: limitApps(["YouTube", "Reddit", "Twitch"]),
  timeLimitMinutes: 45
  ),
  // Index 8 - Coach
  .init(
  name: "Thor Odinson",
  username: "thunder",
  role: .coach,
  streakDays: 9,
  status: .noStatus,
  monitoredApps: limitApps(["TikTok", "Snapchat", "Instagram",
  "YouTube", "Discord"]),
  timeLimitMinutes: 100
  )
  ]
