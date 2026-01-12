//
//  TraineeStatsCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 11/10/25.
//

import SwiftUI
import ManagedSettings

struct TraineeStatsCardView: View {
    private var name: String // TODO: Adjust the fields for when the UserSettings or User is adjusted
    private var streakDays: Int
    private var timeLimitMinutes: Int
    private var monitoredApps: [String]
    private var appTokens: [ApplicationToken]
    private var profilePicUrl: String? = nil
    
    init(
        name: String,
        streakDays: Int,
        timeLimitMinutes: Int,
        monitoredApps: [String],
        appTokens: [ApplicationToken],
        profilePicUrl: String? = nil
    ) {
        self.name = name
        self.streakDays = streakDays
        self.timeLimitMinutes = timeLimitMinutes
        self.monitoredApps = monitoredApps
        self.appTokens = appTokens
        self.profilePicUrl = profilePicUrl
    }
    
    var body: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Color(.white))                 // square background color
            .frame(width: 220, height: 170)
            .overlay(                                   // outline stroke
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color("primaryColor"), lineWidth: 3)
            )
            .overlay(alignment: .topLeading) {
                HStack(alignment: .top) {
                    // Left Column: Profile Stats
                    VStack(alignment: .leading, spacing: 12) {
                        // Small avatar (kept as image; swap to placeholder if needed)
                        Group {
                            if let profilePicUrl, let url = URL(string: profilePicUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                    default:
                                        Image("google-icon").resizable().scaledToFill()
                                    }
                                }
                            } else {
                                Image("google-icon").resizable().scaledToFill()
                            }
                        }
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
                        if !appTokens.isEmpty {
                            ForEach(Array(appTokens.prefix(3).enumerated()), id: \.offset) { _, token in
                                Label(token)
                                    .labelStyle(.titleAndIcon)
                                    .font(.system(size: 13))
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    .frame(width: 95, alignment: .leading)
                                    .clipped()
                                    .allowsTightening(true)
                                    .minimumScaleFactor(0.85)
                            }
                        } else {
                        ForEach(Array(monitoredApps.prefix(3).enumerated()), id: \.offset) { _, app in
                            Text(app)
                                    .font(.system(size: 13, weight: .regular))
                                .lineLimit(1)
                                .truncationMode(.tail)
                                    .frame(width: 95, alignment: .leading)
                                    .clipped()
                                    .allowsTightening(true)
                                    .minimumScaleFactor(0.85)
                            }
                        }
                        if (appTokens.isEmpty ? monitoredApps.count : appTokens.count) > 6 {
                            // vertical ellipsis indicator
                            Text("⋮")
                                .font(.system(size: 14, weight: .semibold))
                                .accessibilityLabel("More apps")
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
    TraineeStatsCardView(
        name: "Peter Parker",
        streakDays: 3,
        timeLimitMinutes: 35,
        monitoredApps: ["Instagram", "Facebook", "TikTok"],
        appTokens: [],
        profilePicUrl: "peter_parker"
    )
}
