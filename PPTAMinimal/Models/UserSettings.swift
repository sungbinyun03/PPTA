//
//  UserSettings.swift
//  PPTA
//
//  Created by Sungbin Yun on 12/30/24.
//

import Foundation
import FamilyControls
import ManagedSettings

struct PeerCoach: Codable, Identifiable {
    let id = UUID()
    let givenName: String
    let familyName: String
    let phoneNumber: String
}

final class UserSettings: Codable {
    
    // MARK: - Properties
    
    var applications: FamilyActivitySelection
    
    var thresholdHour: Int
    var thresholdMinutes: Int
    
    var notificationText: String
    
    var onboardingCompleted: Bool

    var peerCoaches: [PeerCoach]
    
    // MARK: Init
    init(
        applications: FamilyActivitySelection = .init(),
        thresholdHour: Int = 0,
        thresholdMinutes: Int = 0,
        notificationText: String = "",
        onboardingCompleted: Bool = false,
        peerCoaches: [PeerCoach] = []
    ) {
        self.applications = applications
        self.thresholdHour = thresholdHour
        self.thresholdMinutes = thresholdMinutes
        self.notificationText = notificationText
        self.onboardingCompleted = onboardingCompleted
        self.peerCoaches = peerCoaches
    }
}
