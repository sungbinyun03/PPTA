//
//  TraineeStatsCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 11/10/25.
//

import SwiftUI

struct TraineeStatsCardView: View {
    private var name: String // TODO: Adjust the fields for when the UserSettings or User is adjusted
    private var streakDays: Int
    private var timeLimitMinutes: Int
    private var monitoredApps: [String]
    private var profilePicUrl: String? = nil
    
    init(name: String, streakDays: Int, timeLimitMinutes: Int, monitoredApps: [String], profilePicUrl: String? = nil) {
        self.name = name
        self.streakDays = streakDays
        self.timeLimitMinutes = timeLimitMinutes
        self.monitoredApps = monitoredApps
        self.profilePicUrl = profilePicUrl
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(.white))                 // square background color
            .frame(width: 200, height: 170)
            .overlay(                                   // outline stroke
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color("primaryColor"), lineWidth: 3)
            )
            .overlay(alignment: .topLeading) {
                HStack(alignment: .top) {
                    // Left Column: Profile Stats
                    VStack(alignment: .leading, spacing: 12) {
                        // Small avatar (kept as image; swap to placeholder if needed)
                        Image(profilePicUrl ?? "google-icon") // TODO: Display user initials as a default like the ProfileView
                            .resizable()
                            .scaledToFill()
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            .overlay(
                                Circle().stroke(Color("primaryColor"), lineWidth: 3)
                            )
                        Text(name)
                            .font(.system(size: 15, weight: .bold))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 200/2 - 10, alignment: .leading)
                        Text("\(streakDays) day streak")
                            .font(.system(size: 15, weight: .bold))
                        Text("\(timeLimitMinutes) min limit")
                            .font(.system(size: 15, weight: .bold))
                        
                        HStack { Spacer() }
                    }
                    .padding(.leading, 8)
                    .padding(.vertical, 8)
                    
                    // Right Column: Monitored Apps
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(monitoredApps.prefix(3).enumerated()), id: \.offset) { _, app in
                            Text(app)
                                .font(.system(size: 15, weight: .regular)) // TODO: At some point, make it so that the app icons show instead of the name
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: 170/2 - 10, alignment: .leading)
                        }
                        if monitoredApps.count > 6 {
                            // vertical ellipsis indicator
                            Text("⋮")
                                .font(.system(size: 14, weight: .semibold))
                                .accessibilityLabel("\(monitoredApps.count - 3) more apps")
                        }
                    }
                    .frame(alignment: .topLeading)
                    .padding(.trailing, 8)
                    .padding(.vertical, 8)
                }
            }
    }
}

#Preview {
    TraineeStatsCardView(name: "Peter Parker", streakDays: 3, timeLimitMinutes: 35, monitoredApps: ["Instagram", "Facebook", "TikTok"], profilePicUrl: "peter_parker")
}
