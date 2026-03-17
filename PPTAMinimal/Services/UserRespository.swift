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

    /// Normalize phone to a canonical form (10 digits for US) for storage and lookup.
    static func normalizePhoneNumber(_ phoneNumber: String) -> String {
        var normalized = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if normalized.hasPrefix("1"), normalized.count > 10 {
            normalized = String(normalized.dropFirst())
        }
        if normalized.count > 10 {
            normalized = String(normalized.suffix(10))
        }
        return normalized
    }

    /// Fetch a `User` document by uid. Returns nil if not found.
    func fetchUser(by uid: String) async throws -> User? {
        let snapshot = try await db.collection(collectionName).document(uid).getDocument()
        return try snapshot.data(as: User.self)
    }

    /// Find a user by phone number (normalized). Returns nil if not found.
    func findUserByPhone(_ phoneNumber: String) async throws -> User? {
        let normalized = Self.normalizePhoneNumber(phoneNumber)
        guard normalized.count >= 10 else { return nil }
        let query = try await db.collection(collectionName)
            .whereField("phoneNumber", isEqualTo: normalized)
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
