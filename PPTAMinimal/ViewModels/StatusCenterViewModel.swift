//
//  StatusCenterViewModel.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class StatusCenterViewModel: ObservableObject {
    @Published var trainees: [StatusCenterPerson] = []
    @Published var coaches: [StatusCenterPerson] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isPerformingAction = false

    /// Used by the Coaches list to enable "Request Mercy" when the current user is cut off.
    @Published var isCurrentUserCutOff = false

    private let usersRepo = UserRepository()
    private let settingsRepo = UserSettingsRepository()
    private let firestoreService = FirestoreService() // for phone->uid fallback
    private let db = Firestore.firestore()
    private var traineeListeners: [ListenerRegistration] = []

    private var currentUserId: String? { Auth.auth().currentUser?.uid }

    func refresh() async {
        guard let uid = currentUserId else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            let mySettings = try await settingsRepo.fetchSettings(for: uid) ?? UserSettings()
            isCurrentUserCutOff = (mySettings.traineeStatus == .cutOff)

            var coachIds = mySettings.coachIds
            var traineeIds = mySettings.traineeIds

            // Temporary fallback during migration: resolve phone-based lists to uids.
            if coachIds.isEmpty && !mySettings.coaches.isEmpty {
                coachIds = try await resolvePhonesToUids(mySettings.coaches.map(\.phoneNumber))
            }
            if traineeIds.isEmpty && !mySettings.trainees.isEmpty {
                traineeIds = try await resolvePhonesToUids(mySettings.trainees.map(\.phoneNumber))
            }

            // Fetch + map
            let coachPeople = try await fetchPeople(for: coachIds, mySettings: mySettings)
            let traineePeople = try await fetchPeople(for: traineeIds, mySettings: mySettings)

            // For coaches list, isCoach should be true (they coach me), isTrainee false unless both.
            coaches = coachPeople.map { p in
                StatusCenterPerson(
                    id: p.id,
                    name: p.name,
                    profileImageURL: p.profileImageURL,
                    isCoach: true,
                    isTrainee: mySettings.traineeIds.contains(p.id),
                    traineeStatus: nil,
                    streakDays: p.streakDays,
                    timeLimitMinutes: p.timeLimitMinutes,
                    pressureLevel: p.pressureLevel
                )
            }

            trainees = traineePeople.map { p in
                StatusCenterPerson(
                    id: p.id,
                    name: p.name,
                    profileImageURL: p.profileImageURL,
                    isCoach: mySettings.coachIds.contains(p.id),
                    isTrainee: true,
                    traineeStatus: p.traineeStatus,
                    streakDays: p.streakDays,
                    timeLimitMinutes: p.timeLimitMinutes,
                    pressureLevel: p.pressureLevel
                )
            }

            // Attach real-time listeners so coaches see status changes without pulling to refresh.
            let resolvedTraineeIds = Array(Set(traineeIds)).filter { $0 != uid }
            attachTraineeListeners(for: resolvedTraineeIds)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Real-time trainee status listeners

    private func attachTraineeListeners(for traineeIds: [String]) {
        // Remove stale listeners before attaching fresh ones.
        traineeListeners.forEach { $0.remove() }
        traineeListeners = []

        for traineeId in traineeIds {
            let listener = db.collection("userSettings").document(traineeId)
                .addSnapshotListener { [weak self] snapshot, _ in
                    guard let self, let data = snapshot?.data() else { return }

                    let rawStatus = data["traineeStatus"] as? String ?? ""
                    let newStatus = TraineeStatus(rawValue: rawStatus) ?? .noStatus
                    let isTracking = data["isTracking"] as? Bool ?? false
                    let effectiveStatus: TraineeStatus = isTracking ? newStatus : .noStatus

                    // Update in-place without a full re-fetch.
                    if let idx = self.trainees.firstIndex(where: { $0.id == traineeId }) {
                        let existing = self.trainees[idx]
                        // Only replace if status actually changed.
                        if existing.traineeStatus != effectiveStatus {
                            self.trainees[idx] = StatusCenterPerson(
                                id: existing.id,
                                name: existing.name,
                                profileImageURL: existing.profileImageURL,
                                isCoach: existing.isCoach,
                                isTrainee: existing.isTrainee,
                                traineeStatus: effectiveStatus,
                                streakDays: existing.streakDays,
                                timeLimitMinutes: existing.timeLimitMinutes,
                                pressureLevel: existing.pressureLevel
                            )
                        }
                    }
                }
            traineeListeners.append(listener)
        }
    }

    // MARK: - Lock / Release actions

    /// Calls a signed Cloud Run lock or unlock URL in-app (no Safari redirect).
    /// Refreshes trainee list on success.
    func performAction(url: URL, traineeId: String) async {
        isPerformingAction = true
        defer { isPerformingAction = false }
        errorMessage = nil

        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 15
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                errorMessage = "Action failed — please try again."
                return
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func fetchPeople(for uids: [String], mySettings: UserSettings) async throws -> [StatusCenterPerson] {
        // De-dupe and remove self
        guard let me = currentUserId else { return [] }
        let unique = Array(Set(uids)).filter { $0 != me }

        return try await withThrowingTaskGroup(of: StatusCenterPerson?.self) { group in
            for id in unique {
                group.addTask {
                    let user = try await self.usersRepo.fetchUser(by: id)
                    let settings = try await self.settingsRepo.fetchSettings(for: id)

                    let name = user?.name ?? "Unknown"
                    let profileURL = settings?.profileImageURL

                    let streakDays = StreakCalculator.daysSince(
                        start: settings?.startDailyStreakDate,
                        calendar: .current
                    )
                    let timeLimitMinutes = (settings?.thresholdHour ?? 0) * 60 + (settings?.thresholdMinutes ?? 0)
                    
                    let effectiveStatus: TraineeStatus?
                    if let settings, settings.isTracking == false {
                        effectiveStatus = .noStatus
                    } else {
                        effectiveStatus = settings?.traineeStatus
                    }

                    return StatusCenterPerson(
                        id: id,
                        name: name,
                        profileImageURL: profileURL,
                        isCoach: mySettings.coachIds.contains(id),
                        isTrainee: mySettings.traineeIds.contains(id),
                        traineeStatus: effectiveStatus,
                        streakDays: streakDays,
                        timeLimitMinutes: timeLimitMinutes,
                        pressureLevel: settings?.pressureLevel ?? .off
                    )
                }
            }
            return try await group.reduce(into: [StatusCenterPerson]()) { acc, maybe in
                if let p = maybe { acc.append(p) }
            }
        }
        .sorted { $0.name < $1.name }
    }

    private func resolvePhonesToUids(_ phones: [String]) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            firestoreService.fetchUsersByAnyPhoneNumbers(phoneNumbers: phones) { users in
                continuation.resume(returning: users.map(\.id))
            }
        }
    }
}



