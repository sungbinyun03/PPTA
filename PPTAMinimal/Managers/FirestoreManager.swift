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
}
