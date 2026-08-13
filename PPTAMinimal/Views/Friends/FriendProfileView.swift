//
//  FriendProfileView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/12/25.
//
import SwiftUI

/// Represents the friendship status between the current user and another user
/// TEMPORARY: Renamed from FriendshipStatus to avoid conflict with another enum in the codebase
enum FriendProfileStatus {
    case notFriend          // Not a friend (same as previous isFriend: false)
    case requestSent        // Current user sent a friend request
    case requestReceived    // Current user received a friend request
    case isFriend           // They are friends (same as previous isFriend: true)
}

struct FriendProfileView: View {
    // MARK: - Properties
    let name: String
    let friendshipStatus: FriendProfileStatus
    let isTrainee: Bool
    let isCoach: Bool
    let profilePicUrl: String?

    // MARK: - Trainee stats
    let traineeStatus: TraineeStatus
    let streakDays: Int
    let timeLimitMinutes: Int
    let pressureLevel: PressureLevel

    let onLock: (() -> Void)?
    let onUnlock: (() -> Void)?
    let lockedByName: String?
    /// Defaulted so existing construction sites keep compiling; the sheet passes the real list.
    var monitoredAppNames: [String] = []
    var monitoredAppStats: [MonitoredAppStat] = []
    var hasPendingMercyRequest: Bool = false

    // MARK: - Role request / relationship actions
    let coachAction: FriendProfileViewModel.ActionConfig
    let traineeAction: FriendProfileViewModel.ActionConfig
    let onCoachPrimary: () -> Void
    let onCoachSecondary: () -> Void
    let onTraineePrimary: () -> Void
    let onTraineeSecondary: () -> Void
    /// Nil hides the row entirely — it only makes sense for an existing friend.
    var onUnfriend: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    private let primaryColor = Color("primaryColor")

    // MARK: - Computed

    private var potentialFriendEmoji: String {
        let emojis = ["🧐", "😎", "🥸", "🤓"]
        let index = abs(name.hashValue) % emojis.count
        return emojis[index]
    }

    private var role: String {
        switch friendshipStatus {
        case .requestSent:     return "Friend request sent"
        case .requestReceived: return "Friend request received"
        case .notFriend:       return "Potential friend \(potentialFriendEmoji)"
        case .isFriend:
            if isCoach && isTrainee { return "Coach & Trainee" }
            else if isCoach         { return "Coach" }
            else if isTrainee       { return "Trainee" }
            else                    { return "Friend" }
        }
    }

    private var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button row
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(primaryColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: Hero — avatar ringed in the person's live status
                        VStack(spacing: 12) {
                            ZStack {
                                // The ring carries the status at a glance, so it reads before
                                // any text does.
                                Circle()
                                    .stroke(heroRingColor, lineWidth: 3)
                                    .frame(width: 94, height: 94)

                                if let profilePicUrl, let url = URL(string: profilePicUrl) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        default:
                                            avatarFallback
                                        }
                                    }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    avatarFallback
                                }
                            }

                            VStack(spacing: 8) {
                                Text(name)
                                    .font(.custom("BambiBold", size: 26))
                                    .foregroundColor(.primary)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 6) {
                                    Text(role.uppercased())
                                        .font(.custom("Satoshi-Variable", size: 10))
                                        .fontWeight(.semibold)
                                        .tracking(1.1)
                                        .foregroundColor(primaryColor)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(primaryColor.opacity(0.12))
                                        .clipShape(Capsule())

                                    statusPill
                                }
                            }
                        }
                        .padding(.top, 4)

                        // Urgent and time-sensitive, so it sits above everything rather than
                        // as a row buried inside the stats card.
                        if hasPendingMercyRequest {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.raised.fill")
                                    .foregroundColor(.white)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Asking you for more time")
                                        .font(.custom("BambiBold", size: 15))
                                        .foregroundColor(.white)
                                    Text("Snooze their lock to give them 10 minutes.")
                                        .font(.custom("Satoshi-Variable", size: 12))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 13)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 20)
                        }

                        // MARK: Lock / Unlock CTAs (coach actions)
                        if let onLock {
                            Button { onLock() } label: {
                                HStack {
                                    Text("Lock")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "lock")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(Color.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.horizontal, 20)
                        }

                        if let onUnlock {
                            let isSnoozed = traineeStatus == .snoozedLock
                            Button { onUnlock() } label: {
                                HStack {
                                    Text("Snooze Lock for 10 Min")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "lock.open")
                                }
                                .foregroundColor(isSnoozed ? .gray : .white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(isSnoozed ? Color(.systemGray5) : primaryColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .disabled(isSnoozed)
                            .padding(.horizontal, 20)
                        }

                        // MARK: Headline stats
                        HStack(spacing: 8) {
                            heroTile(
                                label: "Streak",
                                value: "\(streakDays)",
                                caption: streakDays == 1 ? "day" : "days"
                            )
                            heroTile(
                                label: "Daily limit",
                                value: limitValueText,
                                caption: limitCaptionText
                            )
                            heroTile(
                                label: "Pressure",
                                value: pressureLevel.rawValue,
                                caption: nil,
                                tint: pressureTint
                            )
                        }
                        .padding(.horizontal, 20)

                        if let locker = lockedByName,
                           traineeStatus == .cutOff || traineeStatus == .snoozedLock {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 12))
                                Text("Locked by \(locker)")
                                    .font(.custom("Satoshi-Variable", size: 13))
                                    .fontWeight(.medium)
                                Spacer(minLength: 0)
                            }
                            .foregroundColor(primaryColor)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(primaryColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal, 20)
                        }

                        // Names and counts are learned as the trainee hits lock screens, so
                        // this stands in until they've actually been blocked for something.
                        if !monitoredAppNames.isEmpty, blockedApps.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("MONITORING")
                                    .font(.custom("Satoshi-Variable", size: 11))
                                    .fontWeight(.semibold)
                                    .tracking(1.2)
                                    .foregroundColor(primaryColor.opacity(0.6))
                                Text(monitoredAppNames.joined(separator: " · "))
                                    .font(.custom("Satoshi-Variable", size: 14))
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(primaryColor.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .padding(.horizontal, 20)
                        }

                        if !blockedApps.isEmpty {
                            blockedAppsCard
                                .padding(.horizontal, 20)
                        }

                        // MARK: Action buttons
                        VStack(spacing: 10) {
                            actionButton(
                                title: coachAction.title,
                                isDestructive: coachAction.isDestructive,
                                enabled: friendshipStatus == .isFriend && coachAction.enabled,
                                action: onCoachPrimary
                            )

                            if let secondary = coachAction.secondaryTitle {
                                actionButton(
                                    title: secondary,
                                    isDestructive: false,
                                    enabled: friendshipStatus == .isFriend && coachAction.secondaryEnabled,
                                    action: onCoachSecondary
                                )
                            }

                            actionButton(
                                title: traineeAction.title,
                                isDestructive: traineeAction.isDestructive,
                                enabled: friendshipStatus == .isFriend && traineeAction.enabled,
                                action: onTraineePrimary
                            )

                            if let secondary = traineeAction.secondaryTitle {
                                actionButton(
                                    title: secondary,
                                    isDestructive: false,
                                    enabled: friendshipStatus == .isFriend && traineeAction.secondaryEnabled,
                                    action: onTraineeSecondary
                                )
                            }

                            if let onUnfriend, friendshipStatus == .isFriend {
                                actionButton(
                                    title: "Remove Friend",
                                    isDestructive: true,
                                    enabled: true,
                                    action: onUnfriend
                                )
                                .padding(.top, 8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    // MARK: - Hero helpers

    /// Ring color mirrors the status rings used elsewhere, so the same colour always means
    /// the same thing. Falls back to a neutral ring when there's no trainee status to show.
    private var heroRingColor: Color {
        traineeStatus.ringColor ?? primaryColor.opacity(0.25)
    }

    /// Matches PressureLevelView's colour per tier.
    private var pressureTint: Color {
        switch pressureLevel {
        case .off:      return .secondary
        case .standard: return Color("primaryButtonColor")
        case .hardcore: return primaryColor
        }
    }

    /// Split so the tile can show a big number with a small unit beneath it rather than
    /// cramming "90 min" into one line that has to shrink.
    private var limitValueText: String {
        let hours = timeLimitMinutes / 60
        let minutes = timeLimitMinutes % 60
        if timeLimitMinutes == 0 { return "—" }
        if hours > 0 && minutes > 0 { return "\(hours)h \(minutes)m" }
        if hours > 0 { return "\(hours)" }
        return "\(minutes)"
    }

    private var limitCaptionText: String? {
        let hours = timeLimitMinutes / 60
        let minutes = timeLimitMinutes % 60
        if timeLimitMinutes == 0 { return "not set" }
        if hours > 0 && minutes > 0 { return "per day" }
        return hours > 0 ? (hours == 1 ? "hour" : "hours") : "min"
    }

    private func heroTile(
        label: String,
        value: String,
        caption: String?,
        tint: Color? = nil
    ) -> some View {
        VStack(spacing: 4) {
            Text(label.uppercased())
                .font(.custom("Satoshi-Variable", size: 9.5))
                .fontWeight(.semibold)
                .tracking(0.8)
                .foregroundColor(primaryColor.opacity(0.6))
                .lineLimit(1)

            Text(value)
                .font(.custom("BambiBold", size: 22))
                .foregroundColor(tint ?? .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)

            Text(caption ?? " ")
                .font(.custom("Satoshi-Variable", size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Blocked apps

    /// Apps that actually blocked them at least once. Apps at zero are omitted: a row of
    /// empty bars reads as "no data" and buries the ones that matter.
    private var blockedApps: [MonitoredAppStat] {
        monitoredAppStats.filter { $0.blocks30d > 0 }
    }

    private var totalBlocks: Int { blockedApps.reduce(0) { $0 + $1.blocks30d } }

    /// Bars are scaled against the top app rather than the total, so the leader always fills
    /// the row and the comparison between apps stays legible even when one dominates.
    private var maxBlocks: Int { blockedApps.map(\.blocks30d).max() ?? 1 }

    private var blockedAppsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("BLOCKED · LAST 30 DAYS")
                    .font(.custom("Satoshi-Variable", size: 11))
                    .fontWeight(.semibold)
                    .tracking(1.2)
                    .foregroundColor(primaryColor.opacity(0.6))
                Spacer()
                Text("\(totalBlocks)")
                    .font(.custom("BambiBold", size: 20))
                    .foregroundColor(primaryColor)
            }

            VStack(spacing: 12) {
                ForEach(blockedApps.prefix(5)) { app in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Text(app.name)
                                .font(.custom("Satoshi-Variable", size: 14))
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text("\(app.blocks30d)")
                                .font(.custom("BambiBold", size: 14))
                                .foregroundColor(primaryColor)
                        }
                        blockBar(fraction: CGFloat(app.blocks30d) / CGFloat(maxBlocks))
                    }
                }
            }

            Text("Times \(name.components(separatedBy: " ").first ?? name) opened an app after being locked out.")
                .font(.custom("Satoshi-Variable", size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(primaryColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func blockBar(fraction: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(primaryColor.opacity(0.15))
                Capsule()
                    .fill(primaryColor)
                    // Floor the width so a single block is still a visible mark.
                    .frame(width: max(6, geo.size.width * min(max(fraction, 0), 1)))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Sub-views

    private var avatarFallback: some View {
        Circle()
            .fill(primaryColor.opacity(0.12))
            .frame(width: 80, height: 80)
            .overlay(
                Text(initials)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(primaryColor)
            )
    }

    private var statusPill: some View {
        let text: String = {
            switch traineeStatus {
            case .allClear:        return "All clear"
            case .attentionNeeded: return "Attention needed"
            case .cutOff:          return "Cut off"
            case .snoozedLock:     return "Snoozed Lock"
            case .noStatus:        return "No status"
            }
        }()
        let color = traineeStatus.ringColor ?? Color.secondary
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func actionButton(title: String, isDestructive: Bool, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                Spacer()
            }
            .foregroundColor(
                !enabled ? .secondary :
                isDestructive ? .red :
                primaryColor
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .background(enabled ? primaryColor.opacity(0.1) : primaryColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(!enabled)
    }
}

#Preview {
    FriendProfileView(
        name: "Sungbin Yun",
        friendshipStatus: .isFriend,
        isTrainee: false,
        isCoach: false,
        profilePicUrl: nil,
        traineeStatus: .attentionNeeded,
        streakDays: 6,
        timeLimitMinutes: 90,
        pressureLevel: .standard,
        onLock: nil,
        onUnlock: nil,
        lockedByName: nil,
        coachAction: .init(title: "Request as Coach", enabled: true),
        traineeAction: .init(title: "Request as Trainee", enabled: true),
        onCoachPrimary: {},
        onCoachSecondary: {},
        onTraineePrimary: {},
        onTraineeSecondary: {}
    )
}
