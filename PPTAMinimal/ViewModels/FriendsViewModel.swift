//
//  FriendsViewModel.swift
//  PPTAMinimal
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import Combine
import FirebaseAuth
import Contacts

final class FriendsViewModel: ObservableObject {
    @Published var friends: [User] = []
    @Published var incomingRequests: [(friendship: Friendship, user: User)] = []
    @Published var outgoingRequests: [(friendship: Friendship, user: User)] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let friendships = FriendshipRepository()
    private let users = UserRepository()
    
    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }
    
    @MainActor
    func refresh() async {
        guard let uid = currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        
        do {
            let accepted = try await friendships.fetchAcceptedFriendships(for: uid)
            let acceptedUserIds = accepted.map { $0.requesterId == uid ? $0.requesteeId : $0.requesterId }
            let acceptedUsers = try await withThrowingTaskGroup(of: User?.self) { group in
                for id in acceptedUserIds {
                    group.addTask { try await self.users.fetchUser(by: id) }
                }
                return try await group.reduce(into: [User]()) { acc, maybe in
                    if let u = maybe { acc.append(u) }
                }
            }
            let incoming = try await friendships.fetchIncomingRequests(for: uid)
            let incomingPairs = try await withThrowingTaskGroup(of: (Friendship, User?) .self) { group in
                for fr in incoming {
                    group.addTask { (fr, try await self.users.fetchUser(by: fr.requesterId)) }
                }
                return try await group.reduce(into: [(Friendship, User)]()) { acc, pair in
                    if let u = pair.1 { acc.append((pair.0, u)) }
                }
            }
            let outgoing = try await friendships.fetchOutgoingRequests(for: uid)
            let outgoingPairs = try await withThrowingTaskGroup(of: (Friendship, User?) .self) { group in
                for fr in outgoing {
                    group.addTask { (fr, try await self.users.fetchUser(by: fr.requesteeId)) }
                }
                return try await group.reduce(into: [(Friendship, User)]()) { acc, pair in
                    if let u = pair.1 { acc.append((pair.0, u)) }
                }
            }
            
            self.friends = acceptedUsers
            self.incomingRequests = incomingPairs
            self.outgoingRequests = outgoingPairs
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func addFriend(byPhone rawPhone: String) async {
        errorMessage = nil
        guard let uid = currentUserId else { return }
        let cleaned = rawPhone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        let normalized = cleaned.hasPrefix("+") ? cleaned : "+1\(cleaned)"
        do {
            guard let other = try await users.findUserByPhone(normalized) else {
                errorMessage = "No user found with that phone."
                return
            }
            if other.id == uid {
                errorMessage = "You cannot add yourself."
                return
            }
            try await friendships.sendFriendRequest(from: uid, to: other.id)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Sends a friend request to a known user id.
    @MainActor
    func addFriend(userId otherUserId: String) async {
        errorMessage = nil
        guard let uid = currentUserId else { return }
        guard otherUserId != uid else {
            errorMessage = "You cannot add yourself."
            return
        }
        do {
            try await friendships.sendFriendRequest(from: uid, to: otherUserId)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Adds friends by extracting phone numbers from selected contacts.
    /// - Note: Uses all phone numbers per contact and de-dupes them.
    @MainActor
    func addFriends(fromContacts contacts: [CNContact]) async {
        guard !contacts.isEmpty else { return }

        // Deduplicate by phone number (after basic cleanup).
        var phones: [String] = []
        var seen = Set<String>()

        for c in contacts {
            for phone in c.phoneNumbers {
                let raw = phone.value.stringValue
                guard !raw.isEmpty else { continue }
                let cleaned = raw.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                let normalized = cleaned.hasPrefix("+") ? cleaned : "+1\(cleaned)"
                if !normalized.isEmpty, !seen.contains(normalized) {
                    seen.insert(normalized)
                    phones.append(normalized)
                }
            }
        }

        if phones.isEmpty {
            errorMessage = "No phone numbers found on selected contacts."
            return
        }

        // Try each phone number; keep going even if some fail.
        var failures: [String] = []
        for phone in phones {
            await addFriend(byPhone: phone)
            if let err = errorMessage {
                failures.append("\(phone): \(err)")
                errorMessage = nil
            }
        }

        if !failures.isEmpty {
            errorMessage = "Some invites failed:\n" + failures.prefix(3).joined(separator: "\n")
        } else {
            errorMessage = nil
        }
    }
    
    @MainActor
    func accept(_ friendshipId: String) async {
        do {
            try await friendships.acceptRequest(friendshipId)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    @MainActor
    func declineOrCancel(_ friendshipId: String) async {
        do {
            try await friendships.declineOrCancelRequest(friendshipId)
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


