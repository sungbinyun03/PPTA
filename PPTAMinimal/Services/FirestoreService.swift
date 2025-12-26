//
//  FirestoreManager.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 2/2/25.
//

import Foundation
import FirebaseFirestore

class FirestoreService {
    private let db = Firestore.firestore()
    
    // Save user settings
    func saveUserSettings(userId: String, settings: UserSettings, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("userSettings").document(userId).setData(from: settings, merge: true) { error in
                completion(error)
            }
        } catch let error {
            completion(error)
        }
    }
    
    // Fetch user settings
    func fetchUserSettings(userId: String, completion: @escaping (UserSettings?, Error?) -> Void) {
        let docRef = db.collection("userSettings").document(userId)
        print("userID: \(userId)")
        
        docRef.getDocument { document, error in
            if let document = document, document.exists {
                print("📄 Document exists, raw data: \(document.data() ?? [:])")
                do {
                    let settings = try document.data(as: UserSettings.self)
                    print("Successfully decoded UserSettings")
                    completion(settings, nil)
                } catch let error {
                    print("Failed to decode UserSettings: \(error)")
                    if let decodingError = error as? DecodingError {
                        switch decodingError {
                        case .keyNotFound(let key, let context):
                            print("Key not found: \(key), context: \(context)")
                        case .typeMismatch(let type, let context):
                            print("Type mismatch: expected \(type), context: \(context)")
                        case .valueNotFound(let type, let context):
                            print("Value not found: \(type), context: \(context)")
                        case .dataCorrupted(let context):
                            print("Data corrupted: \(context)")
                        @unknown default:
                            print("Unknown decoding error: \(error)")
                        }
                    }
                    completion(nil, error)
                }
            } else {
                print("📭 Document does not exist or error: \(error?.localizedDescription ?? "Unknown")")
                completion(nil, error)
            }
        }
    }
    
    // Update user settings
    func updateUserSettings(userId: String, settings: UserSettings, completion: @escaping (Error?) -> Void) {
        do {
            try db.collection("userSettings").document(userId).setData(from: settings, merge: true) { error in
                completion(error)
            }
        } catch let error {
            completion(error)
        }
    }
    
    // Function to normalize phone numbers for consistent comparison
    private func normalizePhoneNumber(_ phoneNumber: String) -> String {
        // Remove all non-numeric characters
        var normalized = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // If number starts with country code "1", remove it
        if normalized.hasPrefix("1") && normalized.count > 10 {
            // Remove the leading "1" if followed by a 10-digit number
            normalized = String(normalized.dropFirst())
        }
        
        // Return just the last 10 digits to handle any other country codes
        if normalized.count > 10 {
            normalized = String(normalized.suffix(10))
        }
        
        return normalized
    }
    
    // Fetch users by phone numbers
    func fetchUsersByPhoneNumbers(phoneNumbers: [String], completion: @escaping ([User]) -> Void) {
        let usersRef = db.collection("users")
        var appUsers: [User] = []
        
        // Create a dispatch group to wait for all queries to complete
        let dispatchGroup = DispatchGroup()
        
        // Normalize all input phone numbers
        let normalizedPhoneNumbers = phoneNumbers.map { normalizePhoneNumber($0) }
        
        // Process phone numbers in batches of 10 (Firestore limit for "in" queries)
        let batchSize = 10
        for i in stride(from: 0, to: normalizedPhoneNumbers.count, by: batchSize) {
            let end = min(i + batchSize, normalizedPhoneNumbers.count)
            let batch = Array(normalizedPhoneNumbers[i..<end])
            
            dispatchGroup.enter()
            
            // First try with the normalized numbers
            usersRef.whereField("phoneNumber", in: batch)
                .getDocuments { (snapshot, error) in
                    // Process any found users
                    if let documents = snapshot?.documents, !documents.isEmpty {
                        for document in documents {
                            do {
                                let user = try document.data(as: User.self)
                                appUsers.append(user)
                            } catch {
                                print("Error decoding user: \(error)")
                            }
                        }
                    }
                    
                    dispatchGroup.leave()
                }
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(appUsers)
        }
    }

    /// Fetch users by phone numbers, attempting multiple common formats for matching.
    /// This helps when the stored `phoneNumber` values are inconsistent (e.g. 10-digit vs E.164).
    ///
    /// - Important: Firestore "in" queries support max 10 values; this method batches automatically.
    func fetchUsersByAnyPhoneNumbers(phoneNumbers: [String], completion: @escaping ([User]) -> Void) {
        let usersRef = db.collection("users")
        var appUsers: [User] = []
        var seenUserIds = Set<String>()

        // Dispatch group to wait for all queries.
        let dispatchGroup = DispatchGroup()

        // Normalize all input phone numbers (10 digits).
        let normalized = phoneNumbers
            .map { normalizePhoneNumber($0) }
            .filter { !$0.isEmpty }

        // Build a candidate set with multiple common stored formats.
        var candidates = Set<String>()
        for n in normalized {
            candidates.insert(n)           // 10-digit
            candidates.insert("1\(n)")     // 11-digit leading 1
            candidates.insert("+1\(n)")    // E.164 for US
        }

        let candidateList = Array(candidates)
        if candidateList.isEmpty {
            completion([])
            return
        }

        // Process in batches of 10 (Firestore limit for "in" queries)
        let batchSize = 10
        for i in stride(from: 0, to: candidateList.count, by: batchSize) {
            let end = min(i + batchSize, candidateList.count)
            let batch = Array(candidateList[i..<end])

            dispatchGroup.enter()

            usersRef.whereField("phoneNumber", in: batch)
                .getDocuments { snapshot, error in
                    if let error {
                        print("FirestoreService.fetchUsersByAnyPhoneNumbers: query error:", error)
                        dispatchGroup.leave()
                        return
                    }

                    if let documents = snapshot?.documents, !documents.isEmpty {
                        for document in documents {
                            do {
                                let user = try document.data(as: User.self)
                                if !seenUserIds.contains(user.id) {
                                    seenUserIds.insert(user.id)
                                    appUsers.append(user)
                                }
                            } catch {
                                print("Error decoding user: \(error)")
                            }
                        }
                    }

                    dispatchGroup.leave()
                }
        }

        dispatchGroup.notify(queue: .main) {
            completion(appUsers)
        }
    }
}
