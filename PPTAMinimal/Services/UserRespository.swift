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
}
