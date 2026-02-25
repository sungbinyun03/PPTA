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
    /// The friend's name
    let name: String
    
    /// The friendship status between current user and this person
    let friendshipStatus: FriendProfileStatus
    
    /// Whether this person is a trainee
    let isTrainee: Bool
    
    /// Whether this person is a coach
    let isCoach: Bool
    
    /// Optional profile picture URL (if nil, shows initials)
    let profilePicUrl: String?
    
    // MARK: - Trainee stats (from their UserSettings)
    let traineeStatus: TraineeStatus
    let streakDays: Int
    let timeLimitMinutes: Int
    let selectedMode: String
    
    /// If non-nil, shows a prominent unlock CTA for coaches.
    let unlockURL: URL?

    // MARK: - Role request / relationship actions (driven by backend)
    let coachAction: FriendProfileViewModel.ActionConfig
    let traineeAction: FriendProfileViewModel.ActionConfig
    let onCoachPrimary: () -> Void
    let onCoachSecondary: () -> Void
    let onTraineePrimary: () -> Void
    let onTraineeSecondary: () -> Void
    
    /// Environment value to dismiss the modal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    // MARK: - Computed Properties
    /// Random emoji for "Potential Friend" role (selected based on name hash for consistency)
    private var potentialFriendEmoji: String {
        let emojis = ["🧐", "😎", "🥸", "🤓"]
        // Use name hash to deterministically select an emoji (consistent for same person)
        let index = abs(name.hashValue) % emojis.count
        return emojis[index]
    }
    
    /// Determines the role string to display based on the relationship flags
    /// Handles combinations: "Coach and Trainee", "Coach", "Trainee", "Friend", or friendship status messages
    private var role: String {
        // First check friendship status for special messages
        switch friendshipStatus {
        case .requestSent:
            return "Friend Request sent!"
        case .requestReceived:
            return "Friend Request Received!"
        case .notFriend:
            return "Potential Friend? \(potentialFriendEmoji)"
        case .isFriend:
            // If they are friends, show coach/trainee status
            if isCoach && isTrainee {
                return "Coach and Trainee"
            } else if isCoach {
                return "Coach"
            } else if isTrainee {
                return "Trainee"
            } else {
                return "Friend"
            }
        }
    }
    
    /// Calculates initials from the name
    private var initials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        // Fallback: take first letter of first and last name
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with close button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(width: 30, height: 30)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Profile picture, name, and role section
                        VStack(spacing: 12) {
                            // Profile picture (image if available, otherwise initials)
                            if let profilePicUrl = profilePicUrl, let url = URL(string: profilePicUrl) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    case .failure(_), .empty:
                                        // Fallback to initials if image fails to load
                                        Circle()
                                            .fill(Color(.tertiarySystemFill))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(initials)
                                                    .font(.system(size: 32, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            )
                                    @unknown default:
                                        Circle()
                                            .fill(Color(.tertiarySystemFill))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(initials)
                                                    .font(.system(size: 32, weight: .semibold))
                                                    .foregroundColor(.primary)
                                            )
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                // Show initials if no profile picture URL
                                Circle()
                                    .fill(Color(.tertiarySystemFill))
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(initials)
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.primary)
                                    )
                            }
                            
                            // Name and role
                            Text(name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.primary)
                            
                            Text(role)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 8)
                        
                        // Coach CTA: Release / Unlock
                        if let unlockURL {
                            Button {
                                openURL(unlockURL)
                            } label: {
                                HStack {
                                    Text(traineeStatus == .attentionNeeded ? "Preemptively Release" : "Release")
                                        .font(.system(size: 16, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color("primaryButtonColor"))
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Status / stats summary
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Status")
                                    .font(.system(size: 14, weight: .medium))
                                Spacer()
                                statusPill
                            }
                            
                            Divider().opacity(0.4)
                            
                            HStack {
                                Text("Daily limit")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(timeLimitMinutes) min")
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Mode")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(selectedMode)
                                    .fontWeight(.semibold)
                            }
                            
                            HStack {
                                Text("Streak")
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(streakDays) days")
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Action buttons section
                        VStack(spacing: 12) {
                            // Request/Remove as Coach button
                            // Enabled only if they are a friend, otherwise disabled
                            Button(action: onCoachPrimary) {
                                HStack {
                                    Text(coachAction.title)
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(friendshipStatus == .isFriend
                                                 ? (coachAction.isDestructive ? .red : (coachAction.enabled ? .primary : .secondary))
                                                 : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(friendshipStatus == .isFriend ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(friendshipStatus != .isFriend || !coachAction.enabled)

                            if let secondary = coachAction.secondaryTitle {
                                Button(action: onCoachSecondary) {
                                    HStack {
                                        Text(secondary)
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.secondarySystemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.separator), lineWidth: 1)
                                            )
                                    )
                                }
                                .disabled(friendshipStatus != .isFriend || !coachAction.secondaryEnabled)
                            }
                            
                            // Request/Remove as Trainee button
                            // Enabled only if they are a friend, otherwise disabled
                            Button(action: onTraineePrimary) {
                                HStack {
                                    Text(traineeAction.title)
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(friendshipStatus == .isFriend
                                                 ? (traineeAction.isDestructive ? .red : (traineeAction.enabled ? .primary : .secondary))
                                                 : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(friendshipStatus == .isFriend ? Color(.secondarySystemBackground) : Color(.tertiarySystemBackground))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color(.separator), lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(friendshipStatus != .isFriend || !traineeAction.enabled)

                            if let secondary = traineeAction.secondaryTitle {
                                Button(action: onTraineeSecondary) {
                                    HStack {
                                        Text(secondary)
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.secondarySystemBackground))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color(.separator), lineWidth: 1)
                                            )
                                    )
                                }
                                .disabled(friendshipStatus != .isFriend || !traineeAction.secondaryEnabled)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    private var statusPill: some View {
        let (text, color): (String, Color) = {
            switch traineeStatus {
            case .allClear: return ("All clear", .green)
            case .attentionNeeded: return ("Attention needed", .red)
            case .cutOff: return ("Cut off", Color(white: 0.25))
            case .noStatus: return ("No status", .gray)
            }
        }()
        
        return Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

#Preview {
    // Sample data similar to StatusCenterView style
    // Example showing "Potential Friend" (not a friend yet)
    FriendProfileView(
        name: "Sungbin Yun",
        friendshipStatus: .isFriend,
        isTrainee: false,
        isCoach: false,
        profilePicUrl: nil,
        traineeStatus: .attentionNeeded,
        streakDays: 6,
        timeLimitMinutes: 90,
        selectedMode: "Coach",
        unlockURL: nil,
        coachAction: .init(title: "Request as Coach", enabled: true),
        traineeAction: .init(title: "Request as Trainee", enabled: true),
        onCoachPrimary: {},
        onCoachSecondary: {},
        onTraineePrimary: {},
        onTraineeSecondary: {}
    )
}
