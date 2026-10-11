//
//  FriendshipRepository.swift
//  PPTAMinimal
//
//  Created by Assistant on 11/11/25.
//

import Foundation
import FirebaseFirestore

final class FriendshipRepository {
    private let db = Firestore.firestore()
    private let collection = "friendships"
    private let usersCollection = "users"

    /// All friendship writes go through the Cloud Run relationships service (`role-requests`),
    /// which also owns unfriending and coach/trainee requests. Server-side means the other person
    /// gets a push even when their app is closed, and requests are validated and deduped. Reads
    /// stay direct Firestore queries/listeners.
    private let http = CloudRunHTTPClient(baseURL: CloudRunConfig.roleRequestsBaseURL)

    // MARK: - Writes (Cloud Run)

    /// Sends a friend request. If they already sent one to this user, the server accepts theirs
    /// instead; if ours is already pending, it's a no-op. Throws "You're already friends." /
    /// "No user found." as user-facing messages.
    func sendFriendRequest(to requesteeId: String) async throws {
        try await http.postJSON("", body: ["action": "sendFriendRequest", "targetId": requesteeId])
    }

    /// Accepts a request sent to this user. Safe to repeat.
    func acceptRequest(_ friendshipId: String) async throws {
        try await http.postJSON("", body: ["action": "acceptFriendRequest", "id": friendshipId])
    }

    /// Declines a request sent to this user. Safe to repeat.
    func declineRequest(_ friendshipId: String) async throws {
        try await http.postJSON("", body: ["action": "declineFriendRequest", "id": friendshipId])
    }

    /// Withdraws a request this user sent. Safe to repeat.
    func cancelRequest(_ friendshipId: String) async throws {
        try await http.postJSON("", body: ["action": "cancelFriendRequest", "id": friendshipId])
    }

    // MARK: - Reads (Firestore)
    
    func fetchIncomingRequests(for userId: String) async throws -> [Friendship] {
        let snap = try await db.collection(collection)
            .whereField("requesteeId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        return try snap.documents.map { try $0.data(as: Friendship.self) }
    }
    
    func fetchOutgoingRequests(for userId: String) async throws -> [Friendship] {
        let snap = try await db.collection(collection)
            .whereField("requesterId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.pending.rawValue)
            .getDocuments()
        return try snap.documents.map { try $0.data(as: Friendship.self) }
    }
    
    func fetchAcceptedFriendships(for userId: String) async throws -> [Friendship] {
        let a = try await db.collection(collection)
            .whereField("requesterId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        let b = try await db.collection(collection)
            .whereField("requesteeId", isEqualTo: userId)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .getDocuments()
        let docs = a.documents + b.documents
        return try docs.map { try $0.data(as: Friendship.self) }
    }

    /// Deletes every friendship document that involves `uid` (as requester or requestee).
    /// Used when a user deletes their account so no dangling relationships remain.
    func deleteAllInvolving(uid: String) async throws {
        let asRequester = try await db.collection(collection)
            .whereField("requesterId", isEqualTo: uid)
            .getDocuments()
        let asRequestee = try await db.collection(collection)
            .whereField("requesteeId", isEqualTo: uid)
            .getDocuments()
        for doc in asRequester.documents + asRequestee.documents {
            try await doc.reference.delete()
        }
    }

    /// Ends the friendship between the caller and `otherId`, and everything hanging off it:
    /// every friendship document between the pair (both directions, any status), any coach or
    /// trainee relationship in either direction, and the `roleRequests` documents that created
    /// them — leaving those behind would make `createRoleRequest` reject the pair with
    /// `ALREADY_ACCEPTED` if they ever became friends again.
    ///
    /// Succeeds even when there is nothing left to delete, so a half-broken pair can always be
    /// cleaned up. Throws with a user-facing message if the caller is currently shielded and
    /// `otherId` is one of their coaches.
    func unfriend(otherId: String) async throws {
        try await http.postJSON("", body: ["action": "unfriend", "otherId": otherId])
    }

    /// Returns true if `a` and `b` have an accepted friendship in either direction.
    /// Runs both directional queries concurrently rather than sequentially.
    func areFriends(_ a: String, _ b: String) async throws -> Bool {
        async let forward = db.collection(collection)
            .whereField("requesterId", isEqualTo: a)
            .whereField("requesteeId", isEqualTo: b)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .limit(to: 1)
            .getDocuments()
        async let reverse = db.collection(collection)
            .whereField("requesterId", isEqualTo: b)
            .whereField("requesteeId", isEqualTo: a)
            .whereField("status", isEqualTo: FriendshipStatus.accepted.rawValue)
            .limit(to: 1)
            .getDocuments()
        let (q1, q2) = try await (forward, reverse)
        return !q1.documents.isEmpty || !q2.documents.isEmpty
    }
}


