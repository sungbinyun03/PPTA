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
    
    func sendFriendRequest(from requesterId: String, to requesteeId: String) async throws {
        let doc = db.collection(collection).document()
        let friendship = Friendship(
            id: doc.documentID,
            requesterId: requesterId,
            requesteeId: requesteeId,
            status: .pending,
            createdAt: Date()
        )
        try doc.setData(from: friendship)
    }
    
    func acceptRequest(_ friendshipId: String) async throws {
        try await db.collection(collection).document(friendshipId).updateData([
            "status": FriendshipStatus.accepted.rawValue
        ])
    }
    
    func declineOrCancelRequest(_ friendshipId: String) async throws {
        try await db.collection(collection).document(friendshipId).delete()
    }
    
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
}


