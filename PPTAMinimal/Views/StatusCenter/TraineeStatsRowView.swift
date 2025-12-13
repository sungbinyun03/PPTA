//
//  TraineeCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 11/10/25.
//

import SwiftUI

struct TraineeStatsRowView: View {
    // Feed accepts a list of trainees to render
    let trainees: [DummyProfile]
    
    // Optional callback when a trainee card is tapped
    var onTraineeTapped: ((DummyProfile) -> Void)?
    
    init(trainees: [DummyProfile], onTraineeTapped: ((DummyProfile) -> Void)? = nil) {
        self.trainees = trainees
        self.onTraineeTapped = onTraineeTapped
    }

    var body: some View {
        // Outer padding so the rounded container doesn't touch screen edges
        VStack {
            VStack(alignment: .leading, spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(trainees) { trainee in // TODO: Needs to be adjusted when fields get adjusted
                            Button(action: {
                                onTraineeTapped?(trainee)
                            }) {
                                TraineeStatsCardView(
                                    name: trainee.name,
                                    streakDays: trainee.streakDays,
                                    timeLimitMinutes: trainee.timeLimitMinutes,
                                    monitoredApps: trainee.monitoredApps,
                                    profilePicUrl: nil
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
    // Minimal preview using the dummy data declared in StatusCenterView.swift
    TraineeStatsRowView(trainees: [.init(
        name: "Peter Parker",
        username: "spidey",
        role: .trainee,
        streakDays: 6,
        status: .allClear,
        monitoredApps: ["TikTok", "Instagram", "YouTube"],
        timeLimitMinutes: 90
        )])
}
