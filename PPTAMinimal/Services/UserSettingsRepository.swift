//
//  UserSettingsRepository.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseFirestore

final class UserSettingsRepository {
    private let db = Firestore.firestore()
    private let collection = "userSettings"

    func fetchSettings(for uid: String) async throws -> UserSettings? {
        let snap = try await db.collection(collection).document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: UserSettings.self)
    }
}



