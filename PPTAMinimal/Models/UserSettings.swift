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

/// Trainee pressure mode. Persisted as `selectedMode` in Firestore (`Off`, `Standard`, `Hardcore`).
enum PressureLevel: String, Codable, CaseIterable, Equatable, Sendable {
    case off = "Off"
    case standard = "Standard"
    case hardcore = "Hardcore"

    /// `true` when the user is in Standard or Hardcore (participates in tracking).
    var isTracking: Bool {
        self != PressureLevel.off
    }

    /// Maps stored / legacy Firestore strings to one canonical case.
    init(decodingFirestore raw: String) {
        switch raw {
        case "Off": self = PressureLevel.off
        case "Standard": self = PressureLevel.standard
        case "Hardcore": self = PressureLevel.hardcore
        case "Chill", "Coach": self = PressureLevel.standard
        case "Hard": self = PressureLevel.hardcore
        default: self = PressureLevel.off
        }
    }
}

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
    /// Persisted under Firestore key `selectedMode` for backward compatibility.
    var pressureLevel: PressureLevel = PressureLevel.off
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
    /// Kept in sync with `pressureLevel`: `false` when `PressureLevel.off`, otherwise `true` (on decode and in `UserSettingsManager.saveSettings`).
    var isTracking: Bool
    
    /// Status visible to this user's coaches / trainees.
    var traineeStatus: TraineeStatus
    
    private enum CodingKeys: String, CodingKey {
        case applications, thresholdHour, thresholdMinutes,
             pressureLevel = "selectedMode",
             onboardingCompleted,
             peerCoaches, profileImageURL,
             coaches, trainees,
             coachIds, traineeIds,
             startDailyStreakDate,
             isTracking, traineeStatus
    }

    /// Single definition of “viable” limits (used by Home, save validation, etc.).
    /// Daily limit > 0 **and** at least one app or category in Screen Time.
    static func appLimitsAreViable(
        thresholdHour: Int,
        thresholdMinutes: Int,
        applications: FamilyActivitySelection
    ) -> Bool {
        let totalMinutes = thresholdHour * 60 + thresholdMinutes
        guard totalMinutes > 0 else { return false }
        return !applications.applicationTokens.isEmpty || !applications.categoryTokens.isEmpty
    }

    /// Daily limit > 0 and at least one app or category in the Screen Time (`FamilyActivitySelection`) picker.
    var hasViableAppLimits: Bool {
        Self.appLimitsAreViable(
            thresholdHour: thresholdHour,
            thresholdMinutes: thresholdMinutes,
            applications: applications
        )
    }
    
    
    // MARK: Init
    /// Default **new-user** state: `pressureLevel` Off, daily limit 0h 0m, empty app selection, not onboarded.
    init(
        id: String? = nil,
        applications: FamilyActivitySelection = .init(),
        thresholdHour: Int = 0,
        thresholdMinutes: Int = 0,
        pressureLevel: PressureLevel = PressureLevel.off,
        onboardingCompleted: Bool = false,
        peerCoaches: [PeerCoach] = [],
        coaches: [PeerCoach] = [],
        trainees: [PeerCoach] = [],
        coachIds: [String] = [],
        traineeIds: [String] = [],
        startDailyStreakDate: Date? = nil,
        traineeStatus: TraineeStatus = .allClear
    ) {
        self.id = id
        self.applications = applications
        self.thresholdHour = thresholdHour
        self.thresholdMinutes = thresholdMinutes
        self.pressureLevel = pressureLevel
        self.onboardingCompleted = onboardingCompleted
        self.peerCoaches = peerCoaches
        self.coaches = coaches
        self.trainees = trainees
        self.coachIds = coachIds
        self.traineeIds = traineeIds
        self.startDailyStreakDate = startDailyStreakDate
        self.isTracking = self.pressureLevel.isTracking
        self.traineeStatus = traineeStatus
    }
    
    // MARK: - Custom Decoding
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Be defensive: existing Firestore docs may be missing keys or have older schemas.
        // Using `try?` avoids hard failures like:
        // "The data couldn’t be read because it is missing."
        applications = (try? container.decode(FamilyActivitySelection.self, forKey: .applications)) ?? .init()
        thresholdHour = (try? container.decode(Int.self, forKey: .thresholdHour)) ?? 0
        thresholdMinutes = (try? container.decode(Int.self, forKey: .thresholdMinutes)) ?? 0
        let rawLevel = (try? container.decode(String.self, forKey: .pressureLevel)) ?? "Off"
        pressureLevel = PressureLevel(decodingFirestore: rawLevel)
        onboardingCompleted = (try? container.decode(Bool.self, forKey: .onboardingCompleted)) ?? false

        peerCoaches = (try? container.decode([PeerCoach].self, forKey: .peerCoaches)) ?? []
        coaches = (try? container.decode([PeerCoach].self, forKey: .coaches)) ?? []
        trainees = (try? container.decode([PeerCoach].self, forKey: .trainees)) ?? []

        coachIds = (try? container.decode([String].self, forKey: .coachIds)) ?? []
        traineeIds = (try? container.decode([String].self, forKey: .traineeIds)) ?? []

        // profileImageURL is stored as URL in newer docs; tolerate string in older docs.
        if let url = try? container.decode(URL.self, forKey: .profileImageURL) {
            profileImageURL = url
        } else if let s = try? container.decode(String.self, forKey: .profileImageURL) {
            profileImageURL = URL(string: s)
        } else {
            profileImageURL = nil
        }

        startDailyStreakDate = try? container.decode(Date.self, forKey: .startDailyStreakDate)
        // Source of truth: Off = no tracking; any other level participates.
        isTracking = pressureLevel.isTracking
        traineeStatus = (try? container.decode(TraineeStatus.self, forKey: .traineeStatus)) ?? .allClear
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(applications, forKey: .applications)
        try container.encode(thresholdHour, forKey: .thresholdHour)
        try container.encode(thresholdMinutes, forKey: .thresholdMinutes)
        try container.encode(pressureLevel, forKey: .pressureLevel)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encode(peerCoaches, forKey: .peerCoaches)
        try container.encodeIfPresent(profileImageURL, forKey: .profileImageURL)
        try container.encode(coaches, forKey: .coaches)
        try container.encode(trainees, forKey: .trainees)
        try container.encode(coachIds, forKey: .coachIds)
        try container.encode(traineeIds, forKey: .traineeIds)
        try container.encodeIfPresent(startDailyStreakDate, forKey: .startDailyStreakDate)
        try container.encode(isTracking, forKey: .isTracking)
        try container.encode(traineeStatus, forKey: .traineeStatus)
    }
    
    
}
