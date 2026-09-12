//
//  SetupCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

/// The first thing a user sees on Home after finishing onboarding.
///
/// It used to be a flat to-do list of five missing items, which meant the reward for completing
/// onboarding was being told you hadn't onboarded. Now onboarding configures apps, limit, and
/// pressure itself, so the only thing legitimately outstanding at that point is a coach — and a
/// coach can't be self-served, it needs someone else to tap Accept.
///
/// So there are two states: a genuine "waiting on them" card when the setup is done and only the
/// acceptance is missing, and the original checklist for anything actually left undone.
struct SetupCardView: View {
    @StateObject private var friendsVm = FriendsViewModel()
    @ObservedObject private var settingsMgr = UserSettingsManager.shared

    /// Coach requests that have gone out but haven't been accepted — either parked waiting on a
    /// friendship (`PendingCoachRequestStore`) or live on the server as a pending role request.
    @State private var awaitingCoachNames: [String] = []
    @State private var awaitingCoachCount: Int = 0

    private var hasCoach: Bool {
        !settingsMgr.userSettings.coachIds.isEmpty || !settingsMgr.userSettings.coaches.isEmpty
    }

    private var isConfigured: Bool {
        settingsMgr.userSettings.hasViableAppLimits && settingsMgr.userSettings.pressureLevel != .off
    }

    private var missingItems: [String] {
        var items: [String] = []
        // Pressure Level now lives inside App Limits, so a single "App Limits" item covers a missing
        // time limit, no apps, or pressure still Off.
        if !settingsMgr.userSettings.hasViableAppLimits || settingsMgr.userSettings.pressureLevel == .off {
            items.append("App Limits")
        }
        if friendsVm.friends.isEmpty { items.append("Friends") }
        if settingsMgr.userSettings.traineeIds.isEmpty && settingsMgr.userSettings.trainees.isEmpty {
            items.append("Trainees")
        }
        // An outstanding request is not a missing step — the user did their part and is waiting on
        // someone else. Listing it as "Coaches" told them to go do a thing they had already done.
        if !hasCoach && awaitingCoachCount == 0 {
            items.append("Coaches")
        }
        return items
    }

    /// True when everything the user controls is done and only an acceptance is outstanding.
    private var isAwaitingCoach: Bool {
        isConfigured && !hasCoach && awaitingCoachCount > 0
    }

    var body: some View {
        Group {
            if isAwaitingCoach {
                awaitingCoachCard
            } else if !missingItems.isEmpty {
                setupCard
            }
        }
        .padding(.horizontal, 24)
        .task {
            await friendsVm.refresh()
            await loadAwaitingCoaches()
        }
    }

    // MARK: - Waiting on a coach

    private var awaitingCoachCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image("onb-waiting")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color("primaryColor"))
                    .frame(width: 34, height: 34)
                Text("Your limit is live")
                    .font(.custom("BambiBold", size: 15))
                    .foregroundColor(Color("primaryColor"))
            }

            Text(limitSummary)
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.primary)

            Text(waitingLine)
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Until someone accepts, nobody can lock you — and nobody can let you back in.")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("primaryColor").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var limitSummary: String {
        let settings = settingsMgr.userSettings
        let count = settings.applications.applicationTokens.count + settings.applications.categoryTokens.count
        var limit: [String] = []
        if settings.thresholdHour > 0 { limit.append("\(settings.thresholdHour)h") }
        if settings.thresholdMinutes > 0 { limit.append("\(settings.thresholdMinutes)m") }
        let limitText = limit.isEmpty ? "No limit" : limit.joined(separator: " ")
        return "\(limitText) across \(count) app\(count == 1 ? "" : "s") · \(settings.pressureLevel.rawValue)"
    }

    private var waitingLine: String {
        if awaitingCoachNames.isEmpty {
            return "Waiting on \(awaitingCoachCount) coach request\(awaitingCoachCount == 1 ? "" : "s") to be accepted."
        }
        let names = ListFormatter.localizedString(byJoining: awaitingCoachNames)
        return "Waiting on \(names) to accept your coach request."
    }

    private func loadAwaitingCoaches() async {
        guard let uid = friendsVm.currentUserId else { return }

        // Parked locally: friendship not accepted yet, so the role request hasn't been sent.
        let parked = PendingCoachRequestStore.pending()

        // Live on the server: sent and pending. `.trainee` is the requester's own role — asking to
        // be someone's trainee is what makes them a coach.
        var liveTargets: [String] = []
        if let outgoing = try? await RoleRequestRepository().fetchOutgoingPending(for: uid) {
            liveTargets = outgoing.filter { $0.role == .trainee }.map(\.targetId)
        }

        let all = Array(Set(parked + liveTargets))
        guard !all.isEmpty else {
            await MainActor.run {
                awaitingCoachCount = 0
                awaitingCoachNames = []
            }
            return
        }

        let repository = UserRepository()
        var names: [String] = []
        for id in all.prefix(3) {
            // `fetchUser` returns `User?` and throws, but `try?` flattens the two optionals into
            // one — so this binding already yields a non-optional `User`.
            if let user = try? await repository.fetchUser(by: id) {
                names.append(user.name.firstNameOnly)
            }
        }

        await MainActor.run {
            awaitingCoachCount = all.count
            awaitingCoachNames = names
        }
    }

    // MARK: - Checklist

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                Text("Setup incomplete")
                    .font(.custom("BambiBold", size: 15))
                    .foregroundColor(.orange)
            }

            Text("Follow the warning icons to set up the following:")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(missingItems, id: \.self) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text(item)
                            .font(.custom("Satoshi-Variable", size: 13))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    SetupCardView()
}
