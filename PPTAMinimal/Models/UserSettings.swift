//
//  UserSettings.swift
//  PPTA
//
//  Created by Sungbin Yun on 12/30/24.
//

import Foundation
import FamilyControls
import ManagedSettings
import FirebaseFirestore

// This struct is the same as Friend
struct PeerCoach: Codable, Identifiable {
    let id = UUID()
    let givenName: String
    let familyName: String
    let phoneNumber: String
    var fcmToken: String?
}

final class UserSettings: Codable {
    // MARK: - Properties
    @DocumentID var id: String? // for Firestore
    var applications: FamilyActivitySelection //selected apps
    var thresholdHour: Int
    var thresholdMinutes: Int
    var selectedMode: String = "Chill"
    var onboardingCompleted: Bool
    var peerCoaches: [PeerCoach] = [] // The same as friends
    var coaches: [PeerCoach] = []
    var trainees: [PeerCoach] = []
    
    /// UID-based role relationships (Option A migration).
    /// Users who coach this user.
    var coachIds: [String] = []
    /// Users this user coaches.
    var traineeIds: [String] = []
    var profileImageURL: URL?
    var startDailyStreakDate: Date?
    
    /// Whether this user is currently participating in tracking.
    /// When false, they should appear with `.noStatus` to their coaches.
    var isTracking: Bool
    
    /// Status visible to this user's coaches / trainees.
    var traineeStatus: TraineeStatus
    
    /// Human‑readable list of monitored apps (e.g. names or bundle IDs),
    /// primarily for display in coach / status center UIs.
    var appList: [String]
    
    private enum CodingKeys: String, CodingKey {
        case applications, thresholdHour, thresholdMinutes,
             selectedMode, onboardingCompleted,
             peerCoaches, profileImageURL,
             coaches, trainees,
             coachIds, traineeIds,
             startDailyStreakDate,
             isTracking, traineeStatus, appList
    }
    
    
    // MARK: Init
    init(
        id: String? = nil,
        applications: FamilyActivitySelection = .init(),
        thresholdHour: Int = 0,
        thresholdMinutes: Int = 0,
        onboardingCompleted: Bool = false,
        peerCoaches: [PeerCoach] = [],
        coaches: [PeerCoach] = [],
        trainees: [PeerCoach] = [],
        coachIds: [String] = [],
        traineeIds: [String] = [],
        startDailyStreakDate: Date? = nil,
        isTracking: Bool = true,
        traineeStatus: TraineeStatus = .allClear,
        appList: [String] = []
    ) {
        self.id = id
        self.applications = applications
        self.thresholdHour = thresholdHour
        self.thresholdMinutes = thresholdMinutes
        self.onboardingCompleted = onboardingCompleted
        self.peerCoaches = peerCoaches
        self.coaches = coaches
        self.trainees = trainees
        self.coachIds = coachIds
        self.traineeIds = traineeIds
        self.startDailyStreakDate = startDailyStreakDate
        self.isTracking = isTracking
        self.traineeStatus = traineeStatus
        self.appList = appList
    }
    
    // MARK: - Custom Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode required fields
        applications = try container.decode(FamilyActivitySelection.self, forKey: .applications)
        thresholdHour = try container.decode(Int.self, forKey: .thresholdHour)
        thresholdMinutes = try container.decode(Int.self, forKey: .thresholdMinutes)
        selectedMode = try container.decode(String.self, forKey: .selectedMode)
        onboardingCompleted = try container.decode(Bool.self, forKey: .onboardingCompleted)
        peerCoaches = try container.decode([PeerCoach].self, forKey: .peerCoaches)
        profileImageURL = try container.decodeIfPresent(URL.self, forKey: .profileImageURL)
        
        // Decode optional fields that might not exist in Firebase
        coaches = try container.decodeIfPresent([PeerCoach].self, forKey: .coaches) ?? []
        trainees = try container.decodeIfPresent([PeerCoach].self, forKey: .trainees) ?? []
        startDailyStreakDate = try container.decodeIfPresent(Date.self, forKey: .startDailyStreakDate)
        isTracking = try container.decodeIfPresent(Bool.self, forKey: .isTracking) ?? true
        traineeStatus = try container.decodeIfPresent(TraineeStatus.self, forKey: .traineeStatus) ?? .allClear
        appList = try container.decodeIfPresent([String].self, forKey: .appList) ?? []
    }
    
    
}
