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
    @State private var showAskCoachInfo = false
    @ObservedObject private var notifications = NotificationManager.shared

    private var snoozeBlue: Color { TraineeStatus.snoozedLock.ringColor ?? .blue }

    /// Left→right: attention needed, cut off & asking me for more time, cut off, snoozed, all clear, not set up.
    /// Stable within a group (enumerated offset breaks ties), so the view model's order is kept.
    private var sortedTrainees: [StatusCenterPerson] {
        func rank(_ t: StatusCenterPerson) -> Int {
            switch t.traineeStatus ?? .noStatus {
            case .attentionNeeded: return 0
            case .cutOff: return t.isRequestingSnoozeFromMe ? 1 : 2
            case .snoozedLock: return 3
            case .allClear: return 4
            case .noStatus: return 5
            }
        }
        return viewModel.trainees.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    private func presentAskCoachInfoIfRequested() {
        guard notifications.coachesPopoverRequestedAt != nil, viewModel.isCurrentUserCutOff else { return }
        guard notifications.consumeCoachesPopoverRequest() else { return }
        // The launch facade covers Home on a cold start; a popover presented under it is lost, so
        // wait for it to go. Consumed above, so the 15s window only has to cover reaching here.
        // Short delay: a popover presented mid tab/launch transition is dropped.
        Task { @MainActor in
            await LaunchGate.shared.waitUntilDismissed()
            try? await Task.sleep(nanoseconds: 600_000_000)
            showAskCoachInfo = true
        }
    }

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
                    .popover(isPresented: $showTraineesInfo, arrowEdge: .bottom) {
                        Text("Add a friend, then tap their profile to request them as your Trainee so you can start holding them accountable once they accept.")
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
                    .popover(isPresented: $showAttentionInfo, arrowEdge: .bottom) {
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
            // Shield-notification tap: open the ask-a-coach popover. Runs on appear (cold launch,
            // flag set before this view existed), on a new request (warm), and when the cut-off
            // state arrives (the button only exists while cut off, and that loads async on launch).
            .onAppear { presentAskCoachInfoIfRequested() }
            .onReceive(notifications.$coachesPopoverRequestedAt) { _ in presentAskCoachInfoIfRequested() }
            .onChange(of: viewModel.isCurrentUserCutOff) { _, _ in presentAskCoachInfoIfRequested() }
            ScrollView(.horizontal) {
                HStack(spacing: 40) {
                    ForEach(sortedTrainees) { trainee in
                        let status = trainee.traineeStatus ?? .noStatus
                        Button {
                            selectedPerson = trainee
                        } label: {
                            TraineeCircleView(
                                status: status,
                                name: trainee.name,
                                profilePicUrl: trainee.profileImageURL?.absoluteString,
                                showSetupWarning: status == .noStatus || trainee.timeLimitMinutes == 0,
                                showSnoozeRequest: status == .cutOff && trainee.isRequestingSnoozeFromMe,
                                snoozeRequestNote: status == .cutOff ? trainee.snoozeRequestMessage : nil
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 14)
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
                    .popover(isPresented: $showCoachesInfo, arrowEdge: .bottom) {
                        Text("Add a friend, then tap their profile to request them as your Coach so they can help keep you on track once they accept.")
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(16)
                            .frame(width: 260)
                            .presentationCompactAdaptation(.popover)
                    }
                }
                // While cut off, nudge the trainee to ask a coach for more time — shown even with no
                // coaches (beside the "add a coach" warning above), where it points them to get one.
                if viewModel.isCurrentUserCutOff {
                    Button { showAskCoachInfo = true } label: {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 21, height: 21)
                            .background(Circle().fill(snoozeBlue))
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showAskCoachInfo, arrowEdge: .bottom) {
                        Text("Open a coach's profile and tap Request to snooze your lock for 10 minutes.")
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
                        let action = viewModel.coachActions[coach.id]
                        Button {
                            selectedPerson = coach
                        } label: {
                            TraineeCircleView(
                                status: .noStatus,
                                name: coach.name,
                                profilePicUrl: coach.profileImageURL?.absoluteString,
                                lockBadge: action?.lock,
                                lockTooltip: action?.tooltip(coachFirstName: coach.name.firstNameOnly),
                                halo: action?.halo ?? false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 35)
                .padding(.vertical, 14)
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
