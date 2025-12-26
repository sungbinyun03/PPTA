//
//  TraineeCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 11/10/25.
//

import SwiftUI

struct TraineeStatsRowView: View {
    // Feed accepts a list of trainees to render
    let trainees: [StatusCenterPerson]
    
    // Optional callback when a trainee card is tapped
    var onTraineeTapped: ((StatusCenterPerson) -> Void)?
    
    init(trainees: [StatusCenterPerson], onTraineeTapped: ((StatusCenterPerson) -> Void)? = nil) {
        self.trainees = trainees
        self.onTraineeTapped = onTraineeTapped
    }

    var body: some View {
        // Outer padding so the rounded container doesn't touch screen edges
        VStack {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trainees) { trainee in
                            Button(action: {
                                onTraineeTapped?(trainee)
                            }) {
                                TraineeStatsCardView(
                                    name: trainee.name,
                                    streakDays: trainee.streakDays,
                                    timeLimitMinutes: trainee.timeLimitMinutes,
                                    monitoredApps: trainee.monitoredApps,
                                    profilePicUrl: trainee.profileImageURL?.absoluteString
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color("primaryButtonColor"))
            )
        }
        .padding(.horizontal, 12)
    }
}

#Preview {
    TraineeStatsRowView(trainees: [
        .init(
            id: "preview-user",
            name: "Peter Parker",
            profileImageURL: nil,
            isCoach: false,
            isTrainee: true,
            traineeStatus: .attentionNeeded,
            streakDays: 6,
            timeLimitMinutes: 90,
            monitoredApps: ["TikTok", "Instagram", "YouTube"]
        )
    ])
}
