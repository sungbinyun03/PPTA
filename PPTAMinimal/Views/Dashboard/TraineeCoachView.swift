//
//  TraineeCoachView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCoachView: View {
    @StateObject private var viewModel = TraineeCoachViewModel()
    var body: some View {
        VStack(alignment:.leading, spacing: 0) {
            Text("Trainees")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20)) // TODO: Adjust font
                .padding(.horizontal, 35)
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(0 ..< viewModel.trainees.count) { index in
                        TraineeCircleView(
                            viewModel: viewModel,
                            index: index,
                            status: statusForIndex(index),
                            name: "\(viewModel.trainees[index].givenName)"
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
                    ForEach(0 ..< viewModel.coaches.count) { index in
                        TraineeCircleView(                              // TODO: Once the fetch logic and PeerCoach properties are adjusted, create a new 
                            viewModel: viewModel,
                            index: index,
                            status: TraineeStatus.noStatus,
                            name: "\(viewModel.trainees[index].givenName)"
                        )
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// TODO: Helper function until PeerCoach struct is updated with status field
private func statusForIndex(_ i: Int) -> TraineeStatus {
    switch i % 4 {
    case 0: return .allClear
    case 1: return .attentionNeeded
    case 2: return .cutOff
    default: return .noStatus
  }
}

#Preview {
    TraineeCoachView()
}
