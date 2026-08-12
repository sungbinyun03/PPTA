//
//  TraineeCoachView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCoachView: View {
    @EnvironmentObject private var viewModel: StatusCenterViewModel
    @State private var selectedPerson: StatusCenterPerson? = nil
    @State private var showTraineesInfo = false
    @State private var showAttentionInfo = false
    @State private var showCoachesInfo = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text("Trainees")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                if viewModel.trainees.isEmpty {
                    Button { showTraineesInfo = true } label: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTraineesInfo) {
                        Text("Add a friend, then tap their profile to request them as your Trainee so you can start holding them accountable.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(width: 260)
                            .presentationCompactAdaptation(.popover)
                    }
                } else if viewModel.trainees.contains(where: { $0.traineeStatus == .attentionNeeded }) {
                    Button { showAttentionInfo = true } label: {
                        Image(systemName: "exclamationmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAttentionInfo) {
                        Text("Your trainee(s) has hit their screen time limit (red ring) — open their profile and cut them off!")
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
                        let status = trainee.traineeStatus ?? .noStatus
                        Button {
                            selectedPerson = trainee
                        } label: {
                            TraineeCircleView(
                                status: status,
                                name: trainee.name,
                                profilePicUrl: trainee.profileImageURL?.absoluteString,
                                showSetupWarning: status == .noStatus || trainee.timeLimitMinutes == 0
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
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showCoachesInfo) {
                        Text("Add a friend, then tap their profile to request them as your Coach so they can help keep you on track.")
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
        // The sheet can end the relationship (unfriend, remove as coach/trainee), so re-read
        // the circles on dismiss instead of waiting for `.task` to run again on next appear.
        .sheet(item: $selectedPerson, onDismiss: { Task { await viewModel.refresh() } }) { person in
            FriendProfileSheetView(otherUserId: person.id, snapshot: person.profileSnapshot)
        }
    }
}

#Preview {
    TraineeCoachView()
        .environmentObject(StatusCenterViewModel())
}
