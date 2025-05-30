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
                do {
                    let settings = try document.data(as: UserSettings.self)
                    completion(settings, nil)
                } catch let error {
                    completion(nil, error)
                }
            } else {
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
}
