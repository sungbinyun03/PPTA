//
//  TraineeCoachView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCoachView: View {
    @StateObject private var viewModel = StatusCenterViewModel()
    var body: some View {
        VStack(alignment:.leading, spacing: 0) {
            Text("Trainees")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20)) // TODO: Adjust font
                .padding(.horizontal, 35)
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(viewModel.trainees) { trainee in
                        TraineeCircleView(
                            status: trainee.traineeStatus ?? .noStatus,
                            name: trainee.name,
                            profilePicUrl: trainee.profileImageURL?.absoluteString
                        )
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            Text("Coaches")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20)) // TODO: Adjust font
                .padding(.horizontal, 35)
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(viewModel.coaches) { coach in
                        TraineeCircleView(
                            status: .noStatus,
                            name: coach.name,
                            profilePicUrl: coach.profileImageURL?.absoluteString
                        )
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .task { await viewModel.refresh() }
  }
}

#Preview {
    TraineeCoachView()
}
