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
    
    /// List of app names being monitored
    let apps: [String]
    
    /// Optional profile picture URL (if nil, shows initials)
    let profilePicUrl: String?
    
    /// Environment value to dismiss the modal
    @Environment(\.dismiss) private var dismiss
    
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
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top section with close button
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.black)
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
                                            .fill(Color(red: 0.6, green: 0.65, blue: 0.55))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(initials)
                                                    .font(.system(size: 32, weight: .semibold))
                                                    .foregroundColor(.white)
                                            )
                                    @unknown default:
                                        Circle()
                                            .fill(Color(red: 0.6, green: 0.65, blue: 0.55))
                                            .frame(width: 80, height: 80)
                                            .overlay(
                                                Text(initials)
                                                    .font(.system(size: 32, weight: .semibold))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            } else {
                                // Show initials if no profile picture URL
                                Circle()
                                    .fill(Color(red: 0.6, green: 0.65, blue: 0.55)) // Muted olive green
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(initials)
                                            .font(.system(size: 32, weight: .semibold))
                                            .foregroundColor(.white)
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
                        
                        // Apps Being Monitored section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Apps Being Monitored")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            // Show apps if friend, otherwise show message
                            if friendshipStatus == .isFriend {
                                // Horizontal scrolling 3-row layout for apps
                                ScrollView(.horizontal, showsIndicators: false) {
                                    appsGrid
                                }
                            } else {
                                Text("Must be a friend to see Apps monitored")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // Action buttons section
                        VStack(spacing: 12) {
                            // Request/Remove as Coach button
                            // Enabled only if they are a friend, otherwise disabled
                            Button(action: {
                                Task {
                                    // TODO: Implement request/remove as coach logic
                                    if isCoach {
                                        // Remove as coach
                                    } else {
                                        // Request as coach
                                    }
                                }
                            }) {
                                HStack {
                                    Text(isCoach ? "Remove as Coach" : "Request as Coach")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(friendshipStatus == .isFriend ? (isCoach ? .red : .primary) : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(friendshipStatus == .isFriend ? Color.white : Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(friendshipStatus != .isFriend)
                            
                            // Request/Remove as Trainee button
                            // Enabled only if they are a friend, otherwise disabled
                            Button(action: {
                                Task {
                                    // TODO: Implement request/remove as trainee logic
                                    if isTrainee {
                                        // Remove as trainee
                                    } else {
                                        // Request as trainee
                                    }
                                }
                            }) {
                                HStack {
                                    Text(isTrainee ? "Remove as Trainee" : "Request as Trainee")
                                        .font(.system(size: 16, weight: .medium))
                                    Spacer()
                                }
                                .foregroundColor(friendshipStatus == .isFriend ? (isTrainee ? .red : .primary) : .secondary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(friendshipStatus == .isFriend ? Color.white : Color.gray.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.black, lineWidth: 1)
                                        )
                                )
                            }
                            .disabled(friendshipStatus != .isFriend)
                            
                            // Friend request/status buttons based on friendship status
                            switch friendshipStatus {
                            case .notFriend:
                                // Request as Friend button
                                Button(action: {
                                    Task {
                                        // TODO: Implement send friend request logic
                                        dismiss()
                                    }
                                }) {
                                    HStack {
                                        Text("Request as Friend")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    )
                                }
                                
                            case .requestSent:
                                // Cancel Request button
                                Button(action: {
                                    Task {
                                        // TODO: Implement cancel friend request logic
                                        dismiss()
                                    }
                                }) {
                                    HStack {
                                        Text("Cancel Request")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    )
                                }
                                
                            case .requestReceived:
                                // Accept and Decline buttons
                                HStack(spacing: 12) {
                                    Button(action: {
                                        Task {
                                            // TODO: Implement accept friend request logic
                                            dismiss()
                                        }
                                    }) {
                                        HStack {
                                            Text("Accept")
                                                .font(.system(size: 16, weight: .medium))
                                            Spacer()
                                        }
                                        .foregroundColor(.primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.black, lineWidth: 1)
                                                )
                                        )
                                    }
                                    
                                    Button(action: {
                                        Task {
                                            // TODO: Implement decline friend request logic
                                            dismiss()
                                        }
                                    }) {
                                        HStack {
                                            Text("Decline")
                                                .font(.system(size: 16, weight: .medium))
                                            Spacer()
                                        }
                                        .foregroundColor(.red)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.white)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.black, lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                                
                            case .isFriend:
                                // Remove as friend button
                                Button(action: {
                                    Task {
                                        // TODO: Implement remove friend logic
                                        dismiss()
                                    }
                                }) {
                                    HStack {
                                        Text("Remove as friend")
                                            .font(.system(size: 16, weight: .medium))
                                        Spacer()
                                    }
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(Color.black, lineWidth: 1)
                                            )
                                    )
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
        }
    }
    
    // MARK: - Apps Grid View
    /// Creates a 3-row horizontal scrolling grid of app names
    /// Apps flow left to right: first row gets first apps, second row gets next apps, etc.
    private var appsGrid: some View {
        // If no apps, show placeholder
        let allApps = apps.isEmpty ? ["No apps selected"] : apps
        
        // Split apps into 3 rows: apps flow left to right across rows
        // Row 0: indices 0, 3, 6, 9... (every 3rd starting at 0)
        // Row 1: indices 1, 4, 7, 10... (every 3rd starting at 1)
        // Row 2: indices 2, 5, 8, 11... (every 3rd starting at 2)
        let row0 = allApps.enumerated().compactMap { $0.offset % 3 == 0 ? $0.element : nil }
        let row1 = allApps.enumerated().compactMap { $0.offset % 3 == 1 ? $0.element : nil }
        let row2 = allApps.enumerated().compactMap { $0.offset % 3 == 2 ? $0.element : nil }
        let rows = [row0, row1, row2]
        
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(0..<3, id: \.self) { rowIndex in
                HStack(spacing: 12) {
                    ForEach(rows[rowIndex], id: \.self) { appName in
                        Text(appName)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
            }
        }
        .frame(minWidth: UIScreen.main.bounds.width - 80) // Ensure horizontal scrolling works
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
        apps: ["TikTok", "YouTube", "Instagram", "Snapchat", "Reddit", "X", "Twitch"],
        profilePicUrl: nil
    )
}
