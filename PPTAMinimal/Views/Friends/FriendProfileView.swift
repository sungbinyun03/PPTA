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

    let lockURL: URL?
    let unlockURL: URL?

    // MARK: - Role request / relationship actions
    let coachAction: FriendProfileViewModel.ActionConfig
    let traineeAction: FriendProfileViewModel.ActionConfig
    let onCoachPrimary: () -> Void
    let onCoachSecondary: () -> Void
    let onTraineePrimary: () -> Void
    let onTraineeSecondary: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

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

                        // MARK: Avatar + name + role
                        VStack(spacing: 10) {
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

                            Text(name)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundColor(.primary)

                            Text(role)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)

                        // MARK: Lock / Unlock CTAs (coach actions)
                        if let lockURL {
                            Button { openURL(lockURL) } label: {
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

                        if let unlockURL {
                            Button { openURL(unlockURL) } label: {
                                HStack {
                                    Text(traineeStatus == .attentionNeeded ? "Preemptively Release" : "Release")
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "lock.open")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 13)
                                .background(primaryColor)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                            .padding(.horizontal, 20)
                        }

                        // MARK: Stats card
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Status")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                                Spacer()
                                statusPill
                            }

                            Divider().opacity(0.3)

                            statRow(label: "Daily limit", value: "\(timeLimitMinutes) min")
                            statRow(label: "Pressure", value: pressureLevel.rawValue)
                            statRow(label: "Streak", value: "\(streakDays) days")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(primaryColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(.horizontal, 20)

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
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
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
        let (text, color): (String, Color) = {
            switch traineeStatus {
            case .allClear:        return ("All clear", .green)
            case .attentionNeeded: return ("Attention needed", .orange)
            case .cutOff:          return ("Cut off", Color(white: 0.35))
            case .noStatus:        return ("No status", .secondary)
            }
        }()
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.1))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
        }
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
        lockURL: nil,
        unlockURL: nil,
        coachAction: .init(title: "Request as Coach", enabled: true),
        traineeAction: .init(title: "Request as Trainee", enabled: true),
        onCoachPrimary: {},
        onCoachSecondary: {},
        onTraineePrimary: {},
        onTraineeSecondary: {}
    )
}
