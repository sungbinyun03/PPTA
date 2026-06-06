//
//  TraineeCoachView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCoachView: View {
    @StateObject private var viewModel = StatusCenterViewModel()
    @State private var selectedPerson: StatusCenterPerson? = nil
    @State private var showTraineesInfo = false
    @State private var showCoachesInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Trainees")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                if viewModel.trainees.isEmpty {
                    Button { showTraineesInfo = true } label: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTraineesInfo) {
                        Text("Add a friend, then request they become your Trainee to start holding each other accountable.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(width: 260)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .padding(.horizontal, 35)
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(viewModel.trainees) { trainee in
                        Button {
                            selectedPerson = trainee
                        } label: {
                            TraineeCircleView(
                                status: trainee.traineeStatus ?? .noStatus,
                                name: trainee.name,
                                profilePicUrl: trainee.profileImageURL?.absoluteString
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
            HStack(spacing: 6) {
                Text("Coaches")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                if viewModel.coaches.isEmpty {
                    Button { showCoachesInfo = true } label: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCoachesInfo) {
                        Text("Add a friend, then request they become your Coach to help you stay on track.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(width: 260)
                            .presentationCompactAdaptation(.popover)
                    }
                }
            }
            .padding(.horizontal, 35)
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(viewModel.coaches) { coach in
                        Button {
                            selectedPerson = coach
                        } label: {
                            TraineeCircleView(
                                status: .noStatus,
                                name: coach.name,
                                profilePicUrl: coach.profileImageURL?.absoluteString
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 20)
            }
            .scrollIndicators(.hidden)
        }
        .task { await viewModel.refresh() }
        .sheet(item: $selectedPerson) { person in
            FriendProfileSheetView(otherUserId: person.id)
        }
    }
}

#Preview {
    TraineeCoachView()
}
