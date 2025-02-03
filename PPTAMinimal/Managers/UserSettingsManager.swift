//
//  UserSettingsManager.swift
//  PPTAMinimal
//
//  Created by Sungbin on 6/18/24.
//

import Foundation
import FamilyControls
import FirebaseAuth

class UserSettingsManager {
    static let shared = UserSettingsManager()
    private init() {}
    
    private let firestoreService = FirestoreService()
    
    private var userID: String? {
        return Auth.auth().currentUser?.uid
    }

    func saveSettings(_ settings: UserSettings) {
        guard let userID = userID else {
            print("ERROR: No user is logged in. Cannot save settings.")
            return
        }

        firestoreService.saveUserSettings(userId: userID, settings: settings) { error in
            if let error = error {
                print("Failed to save user settings to Firestore: \(error.localizedDescription)")
            } else {
                print("User settings saved successfully for user \(userID)!")
            }
        }
    }
    
    func loadSettings(completion: @escaping (UserSettings) -> Void) {
        guard let userID = userID else {
            print("ERROR: No user is logged in. Cannot load settings.")
            completion(UserSettings()) // Provide default settings
            return
        }

        firestoreService.fetchUserSettings(userId: userID) { settings, error in
            if let settings = settings {
                completion(settings)
            } else if let error = error {
                print("Failed to load user settings from Firestore: \(error.localizedDescription)")
                completion(UserSettings()) // Return default settings if fetch fails
            }
        }
    }
    

    func loadAppTokens(completion: @escaping (FamilyActivitySelection) -> Void) {
        loadSettings { settings in
            completion(settings.applications)
        }

    }
    
    func loadNotificationText(completion: @escaping (String) -> Void) {
        loadSettings { settings in
            completion(settings.notificationText)
        }
    }
    
    func loadHoursAndMinutes(completion: @escaping (TimeInterval) -> Void) {
        loadSettings { settings in
            let hours = settings.thresholdHour
            let minutes = settings.thresholdMinutes
            let totalSeconds = (hours * 3600) + (minutes * 60)
            completion(TimeInterval(totalSeconds))
        }
    }
}
