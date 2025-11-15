//
//  StatusCenterView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 7/10/25.
//

import SwiftUI

struct StatusCenterView: View {
    private var dummyTraineeIdxList: [Int] = [0, 1, 3, 4]
    private var dummyCoachIdxList: [Int] = [2, 4]
    
    private var filteredDummyTrainees: [DummyProfile] { // TODO: remove once we feed in the actual values and info (viewModel)
        dummyTraineeIdxList.compactMap { idx in
            guard idx >= 0 && idx < dummyTrainees.count else { return nil }
            return dummyTrainees[idx]
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 5) {
                    ProfileView(headerPart1: "", headerPart2: "Status Center", subHeader: "Your place for tracking accountability")
                    TraineeStatsRowView(trainees: filteredDummyTrainees)
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
                                if idx >= 0 && idx < dummyTrainees.count {
                                    let t = dummyTrainees[idx]
                                    TraineeCellView(
                                        name: t.name,
                                        status: t.status,
                                        profilePicUrl: nil
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
                            ForEach(dummyCoachIdxList, id: \.self) { idx in
                                if idx >= 0 && idx < dummyCoaches.count {
                                    let c = dummyCoaches[idx]
                                    CoachCellView(
                                        name: c.name,
                                        isCutOff: true, // TODO: Wire it up to the current User's status
                                        profilePicUrl: nil
                                    )
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

  // Sample data
  private let dummyTrainees: [DummyProfile] = [
  .init(
  name: "Peter Parker",
  username: "spidey",
  role: .trainee,
  streakDays: 6,
  status: .allClear,
  monitoredApps: limitApps(["TikTok", "Instagram", "YouTube"]),
  timeLimitMinutes: 90
  ),
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
  .init(
  name: "Kamala Khan",
  username: "msmarvel",
  role: .trainee,
  streakDays: 3,
  status: .attentionNeeded,
  monitoredApps: limitApps(["TikTok", "Snapchat", "Instagram"]),
  timeLimitMinutes: 60
  ),
  .init(
  name: "Kate Bishop",
  username: "hawkeye2",
  role: .trainee,
  streakDays: 21,
  status: .cutOff,
  monitoredApps: limitApps(["Instagram", "X", "YouTube", "Discord",
  "Safari"]),
  timeLimitMinutes: 75
  )
  ]

  private let dummyCoaches: [DummyProfile] = [
  .init(
  name: "Tony Stark",
  username: "ironman",
  role: .coach,
  streakDays: 45,
  status: .allClear,
  monitoredApps: limitApps(["X", "YouTube", "Discord"]),
  timeLimitMinutes: 120
  ),
  .init(
  name: "Steve Rogers",
  username: "cap",
  role: .coach,
  streakDays: 30,
  status: .allClear,
  monitoredApps: limitApps(["Reddit", "Safari"]),
  timeLimitMinutes: 90
  ),
  .init(
  name: "Natasha Romanoff",
  username: "blackwidow",
  role: .coach,
  streakDays: 18,
  status: .attentionNeeded,
  monitoredApps: limitApps(["Instagram", "TikTok"]),
  timeLimitMinutes: 60
  ),
  .init(
  name: "Bruce Banner",
  username: "hulk",
  role: .coach,
  streakDays: 2,
  status: .cutOff,
  monitoredApps: limitApps(["YouTube", "Reddit", "Twitch"]),
  timeLimitMinutes: 45
  ),
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
