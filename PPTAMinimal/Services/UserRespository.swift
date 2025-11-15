//
//  UserRespository.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 2/10/25.
//

import Firebase
import FirebaseFirestore
import Foundation

class UserRepository {
    private let db = Firestore.firestore()
    private let collectionName = "users"

    /// Fetch a `User` document by uid. Returns nil if not found.
    func fetchUser(by uid: String) async throws -> User? {
        let snapshot = try await db.collection(collectionName).document(uid).getDocument()
        return try snapshot.data(as: User.self)
    }

    /// Find a user by an exact phone number match.
    /// Pass phone numbers in the same format you store (e.g., E.164 like +15551234567).
    func findUserByPhone(_ phoneNumber: String) async throws -> User? {
        let query = try await db.collection(collectionName)
            .whereField("phoneNumber", isEqualTo: phoneNumber)
            .limit(to: 1)
            .getDocuments()
        guard let doc = query.documents.first else { return nil }
        return try doc.data(as: User.self)
    }

    /// Save or update a user document in Firestore.
    func saveUser(_ user: User) async throws {
        try db.collection(collectionName)
            .document(user.id)
            .setData(from: user)
    }

    /// Check if a user document exists for the given uid.
    func userExists(_ uid: String) async throws -> Bool {
        let document = try await db.collection(collectionName).document(uid).getDocument()
        return document.exists
    }
    
    func updateUserField(uid: String, field: String, value: Any) async throws {
            try await db.collection(collectionName).document(uid).updateData([field: value])
        }
}
