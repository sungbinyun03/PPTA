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
    /// Default-open tooltips: keys already dismissed, and the order snooze requests first arrived in
    /// (a request has no timestamp). See `TooltipDefaultOpen`.
    @State private var dismissedTooltipKeys: Set<String> = []
    @State private var requestArrival: [String] = []
    /// A shield-notification handoff to the hand-hint popover (limit lock) is on its way: it wins, so no
    /// default-open tooltip.
    @State private var askCoachWins = false
    /// A shield-notification handoff to the lock tooltip of the coach holding my lock: forces it open
    /// (note or fallback sentence, dismissed before or not) until it is closed.
    @State private var handoffLock: (coachId: String, key: String)?
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

    /// Snooze requests that carry a note, keyed by trainee + note so a changed note counts as new.
    private var requestKeys: [String: String] {
        var keys: [String: String] = [:]
        for t in viewModel.trainees where t.traineeStatus == .cutOff && t.isRequestingSnoozeFromMe {
            if let note = t.snoozeRequestMessage { keys[t.id] = "request|\(t.id)|\(note)" }
        }
        return keys
    }

    /// The coach who locked me, while that lock is on.
    private var lockHolderId: String? {
        viewModel.coaches.first { viewModel.coachActions[$0.id]?.lock == .active }?.id
    }

    /// A coach lock is on (the hand hint is for a limit/Hardcore lock only, which has no coach badge).
    private var coachLockActive: Bool {
        viewModel.coachActions.values.contains { $0.lock == .active }
    }

    /// Key of the coach whose lock note should be open: the coach holding my lock, with a note; or the
    /// shield handoff, which opens it regardless.
    private var lockTooltipKey: (coachId: String, key: String)? {
        if let handoffLock, handoffLock.coachId == lockHolderId { return handoffLock }
        guard !askCoachWins, !showAskCoachInfo else { return nil }
        for coach in viewModel.coaches {
            if let a = viewModel.coachActions[coach.id], a.lock == .active, a.lockNote != nil, let id = a.lockId,
               !dismissedTooltipKeys.contains("lock|\(id)") {
                return (coach.id, "lock|\(id)")
            }
        }
        return nil
    }

    /// Coach whose snooze note should be open: a running snooze with a note. Same tier as the lock note
    /// (they are different states, so rarely both), after the ask-a-coach popover.
    private var snoozeTooltipKey: (coachId: String, key: String)? {
        guard !askCoachWins, !showAskCoachInfo, lockTooltipKey == nil else { return nil }
        for coach in viewModel.coaches {
            if let a = viewModel.coachActions[coach.id], a.halo, a.snoozeNote != nil, let id = a.snoozeId,
               !dismissedTooltipKeys.contains("snooze|\(id)") {
                return (coach.id, "snooze|\(id)")
            }
        }
        return nil
    }

    /// Trainee id and key of the latest snooze request to open. One popover at a time: my own lock note
    /// or snooze note (or the ask-a-coach popover) takes precedence.
    private var requestTooltipKey: (traineeId: String, key: String)? {
        guard !askCoachWins, !showAskCoachInfo, lockTooltipKey == nil, snoozeTooltipKey == nil else { return nil }
        let keys = requestKeys
        guard let key = TooltipDefaultOpen.pick(candidates: Array(keys.values).sorted(), arrival: requestArrival,
                                                dismissed: dismissedTooltipKeys),
              let id = keys.first(where: { $0.value == key })?.key else { return nil }
        return (id, key)
    }

    private func trackRequests() {
        let ordered = sortedTrainees.compactMap { requestKeys[$0.id] }
        requestArrival = TooltipDefaultOpen.updatedArrival(requestArrival, candidates: ordered)
        // A request that is gone may be asked again with the same note; that is a new request.
        dismissedTooltipKeys = dismissedTooltipKeys.filter { !$0.hasPrefix("request|") || ordered.contains($0) }
    }

    private func tooltipDismissed(_ key: String) {
        dismissedTooltipKeys.insert(key)
        if handoffLock?.key == key { handoffLock = nil }
    }

    private func presentAskCoachInfoIfRequested() {
        guard notifications.coachesPopoverRequestedAt != nil, viewModel.isCurrentUserCutOff else { return }
        // Coach lock vs limit lock isn't known until the own-settings snapshot lands (re-runs then).
        guard viewModel.hasOwnSettingsSnapshot else { return }
        // A coach lock is on but that coach isn't loaded yet: wait (re-runs when the coaches arrive).
        if coachLockActive && lockHolderId == nil { return }
        guard notifications.consumeCoachesPopoverRequest() else { return }
        // Wins over a default-open tooltip, which then stays closed for this lock/request.
        if let key = lockTooltipKey?.key ?? snoozeTooltipKey?.key ?? requestTooltipKey?.key { dismissedTooltipKeys.insert(key) }
        // Coach lock: open that coach's lock tooltip (the circle waits for the launch gate and the
        // transition itself, like any default-open one).
        if let holder = lockHolderId {
            handoffLock = (holder, "lock|handoff|\(UUID().uuidString)")
            return
        }
        // Limit lock: the hand hint.
        askCoachWins = true
        // The launch facade covers Home on a cold start; a popover presented under it is lost, so
        // wait for it to go. Consumed above, so the 15s window only has to cover reaching here.
        // Short delay: a popover presented mid tab/launch transition is dropped.
        Task { @MainActor in
            await LaunchGate.shared.waitUntilDismissed()
            try? await Task.sleep(nanoseconds: 600_000_000)
            showAskCoachInfo = true
            askCoachWins = false
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
            .onChange(of: viewModel.coaches.map(\.id)) { _, _ in presentAskCoachInfoIfRequested() }
            .onChange(of: viewModel.hasOwnSettingsSnapshot) { _, _ in presentAskCoachInfoIfRequested() }
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
                                snoozeRequestNote: status == .cutOff ? trainee.snoozeRequestMessage : nil,
                                autoOpenKey: requestTooltipKey?.traineeId == trainee.id ? requestTooltipKey?.key : nil,
                                onAutoOpenDismiss: { dismissedTooltipKeys.insert($0) }
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
                // Cut off by the limit / Hardcore (no coach lock, so no lock badge to tap): nudge the trainee
                // to ask a coach for more time — shown even with no coaches (beside the "add a coach"
                // warning above), where it points them to get one. A coach lock explains itself via its badge.
                if viewModel.isCurrentUserCutOff && !coachLockActive {
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
                                halo: action?.halo ?? false,
                                haloTooltip: action?.haloTooltip,
                                autoOpenKey: lockTooltipKey?.coachId == coach.id ? lockTooltipKey?.key
                                    : snoozeTooltipKey?.coachId == coach.id ? snoozeTooltipKey?.key : nil,
                                onAutoOpenDismiss: tooltipDismissed
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
        .onChange(of: requestKeys, initial: true) { _, _ in trackRequests() }
        // The sheet can end the relationship (unfriend, remove as coach/trainee), so re-read
        // the circles on dismiss instead of waiting for `.task` to run again on next appear.
        .sheet(item: $selectedPerson, onDismiss: { Task { await viewModel.refresh() } }) { person in
            FriendProfileSheetView(otherUserId: person.id, snapshot: person.profileSnapshot,
                                   receivedNotes: viewModel.coachActions[person.id]?.receivedNotes ?? [])
        }
    }
}

#Preview {
    TraineeCoachView()
        .environmentObject(StatusCenterViewModel())
}
