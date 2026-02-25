//
//  FriendProfileViewModel.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseAuth

@MainActor
final class FriendProfileViewModel: ObservableObject {
    struct ActionConfig {
        var title: String
        var enabled: Bool
        var isDestructive: Bool = false
        var secondaryTitle: String? = nil
        var secondaryEnabled: Bool = true
    }

    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var name: String = ""
    @Published var profilePicUrl: String? = nil
    
    // Other user's tracking state (from their UserSettings)
    @Published var traineeStatus: TraineeStatus = .noStatus
    @Published var streakDays: Int = 0
    @Published var timeLimitMinutes: Int = 0
    @Published var selectedMode: String = "Chill"

    // Relationship relative to current user
    @Published var isCoach: Bool = false     // other is my coach
    @Published var isTrainee: Bool = false   // other is my trainee
    @Published var friendshipStatus: FriendProfileStatus = .notFriend

    @Published var coachAction = ActionConfig(title: "Request as Coach", enabled: false)
    @Published var traineeAction = ActionConfig(title: "Request as Trainee", enabled: false)

    private let otherUserId: String

    private let usersRepo = UserRepository()
    private let settingsRepo = UserSettingsRepository()
    private let friendships = FriendshipRepository()
    private let roleRequests = RoleRequestRepository()

    private var myUid: String? { Auth.auth().currentUser?.uid }

    init(otherUserId: String) {
        self.otherUserId = otherUserId
    }

    func refresh() async {
        guard let uid = myUid else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            // Load other user's display info + settings
            let otherUser = try await usersRepo.fetchUser(by: otherUserId)
            let otherSettings = try await settingsRepo.fetchSettings(for: otherUserId)

            name = otherUser?.name ?? "Unknown"
            profilePicUrl = otherSettings?.profileImageURL?.absoluteString
            
            // Snapshot the other user's stats for display.
            if let otherSettings {
                selectedMode = otherSettings.selectedMode
                timeLimitMinutes = otherSettings.thresholdHour * 60 + otherSettings.thresholdMinutes
                streakDays = StreakCalculator.daysSince(start: otherSettings.startDailyStreakDate, calendar: .current)
                traineeStatus = otherSettings.isTracking ? otherSettings.traineeStatus : .noStatus
            } else {
                selectedMode = "Chill"
                timeLimitMinutes = 0
                streakDays = 0
                traineeStatus = .noStatus
            }

            // Friends-only policy (client-side gating; server enforces too)
            let friends = try await friendships.areFriends(uid, otherUserId)
            friendshipStatus = friends ? .isFriend : .notFriend

            // Determine role relationship from my uid-based arrays
            let mySettings = try await settingsRepo.fetchSettings(for: uid) ?? UserSettings()
            isCoach = mySettings.coachIds.contains(otherUserId)
            isTrainee = mySettings.traineeIds.contains(otherUserId)

            // Pending role requests (in/out)
            let incoming = try await roleRequests.fetchIncomingPending(for: uid)
            let outgoing = try await roleRequests.fetchOutgoingPending(for: uid)

            let incomingFromOther = incoming.filter { $0.requesterId == otherUserId }
            let outgoingToOther = outgoing.filter { $0.targetId == otherUserId }

            // COACH button controls "other is my coach"
            coachAction = buildCoachAction(
                friends: friends,
                incoming: incomingFromOther,
                outgoing: outgoingToOther
            )

            // TRAINEE button controls "other is my trainee"
            traineeAction = buildTraineeAction(
                friends: friends,
                incoming: incomingFromOther,
                outgoing: outgoingToOther
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Actions

    func performCoachPrimary() async {
        guard let uid = myUid else { return }
        do {
            // other is my coach
            if isCoach {
                // current user is trainee of other
                try await roleRequests.removeRelationship(otherId: otherUserId, role: .trainee)
            } else {
                // If there is an incoming request that would make other my coach, accept it.
                if let incomingId = await findIncomingIdForOtherBecomingMyCoach(uid: uid) {
                    try await roleRequests.accept(id: incomingId)
                } else {
                    // Otherwise, request to be trainee of other (so other becomes my coach)
                    _ = try await roleRequests.createRoleRequest(targetId: otherUserId, role: .trainee)
                }
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performCoachSecondary() async {
        guard let uid = myUid else { return }
        do {
            // Decline incoming request (other wants to coach me) OR cancel outgoing (I requested to be trainee).
            if let incomingId = await findIncomingIdForOtherBecomingMyCoach(uid: uid) {
                try await roleRequests.decline(id: incomingId)
            } else if let outgoingId = await findOutgoingIdForMeBecomingTrainee(uid: uid) {
                try await roleRequests.cancel(id: outgoingId)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performTraineePrimary() async {
        guard let uid = myUid else { return }
        do {
            // other is my trainee (I coach other)
            if isTrainee {
                try await roleRequests.removeRelationship(otherId: otherUserId, role: .coach)
            } else {
                if let incomingId = await findIncomingIdForOtherBecomingMyTrainee(uid: uid) {
                    try await roleRequests.accept(id: incomingId)
                } else {
                    _ = try await roleRequests.createRoleRequest(targetId: otherUserId, role: .coach)
                }
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performTraineeSecondary() async {
        guard let uid = myUid else { return }
        do {
            if let incomingId = await findIncomingIdForOtherBecomingMyTrainee(uid: uid) {
                try await roleRequests.decline(id: incomingId)
            } else if let outgoingId = await findOutgoingIdForMeCoachingOther(uid: uid) {
                try await roleRequests.cancel(id: outgoingId)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Action state mapping

    private func buildCoachAction(friends: Bool, incoming: [RoleRequest], outgoing: [RoleRequest]) -> ActionConfig {
        if !friends {
            return .init(title: "Request as Coach", enabled: false)
        }
        if isCoach {
            return .init(title: "Remove as Coach", enabled: true, isDestructive: true)
        }

        // Incoming: other wants to coach me => role=coach, target=me
        if incoming.contains(where: { $0.targetId == myUid && $0.role == .coach }) {
            return .init(title: "Accept Coach", enabled: true, secondaryTitle: "Decline", secondaryEnabled: true)
        }

        // Outgoing: I want to be trainee of other => role=trainee, target=other
        if outgoing.contains(where: { $0.requesterId == myUid && $0.role == .trainee }) {
            return .init(title: "Sent", enabled: false, secondaryTitle: "Cancel", secondaryEnabled: true)
        }

        return .init(title: "Request as Coach", enabled: true)
    }

    private func buildTraineeAction(friends: Bool, incoming: [RoleRequest], outgoing: [RoleRequest]) -> ActionConfig {
        if !friends {
            return .init(title: "Request as Trainee", enabled: false)
        }
        if isTrainee {
            return .init(title: "Remove as Trainee", enabled: true, isDestructive: true)
        }

        // Incoming: other wants to be trainee of me => role=trainee, target=me
        if incoming.contains(where: { $0.targetId == myUid && $0.role == .trainee }) {
            return .init(title: "Accept Trainee", enabled: true, secondaryTitle: "Decline", secondaryEnabled: true)
        }

        // Outgoing: I want to coach other => role=coach, target=other
        if outgoing.contains(where: { $0.requesterId == myUid && $0.role == .coach }) {
            return .init(title: "Sent", enabled: false, secondaryTitle: "Cancel", secondaryEnabled: true)
        }

        return .init(title: "Request as Trainee", enabled: true)
    }

    // MARK: - Pending request id helpers

    private func findIncomingIdForOtherBecomingMyCoach(uid: String) async -> String? {
        do {
            let incoming = try await roleRequests.fetchIncomingPending(for: uid)
            return incoming.first(where: { $0.requesterId == otherUserId && $0.role == .coach })?.id
        } catch {
            return nil
        }
    }

    private func findIncomingIdForOtherBecomingMyTrainee(uid: String) async -> String? {
        do {
            let incoming = try await roleRequests.fetchIncomingPending(for: uid)
            return incoming.first(where: { $0.requesterId == otherUserId && $0.role == .trainee })?.id
        } catch {
            return nil
        }
    }

    private func findOutgoingIdForMeBecomingTrainee(uid: String) async -> String? {
        do {
            let outgoing = try await roleRequests.fetchOutgoingPending(for: uid)
            return outgoing.first(where: { $0.targetId == otherUserId && $0.role == .trainee })?.id
        } catch {
            return nil
        }
    }

    private func findOutgoingIdForMeCoachingOther(uid: String) async -> String? {
        do {
            let outgoing = try await roleRequests.fetchOutgoingPending(for: uid)
            return outgoing.first(where: { $0.targetId == otherUserId && $0.role == .coach })?.id
        } catch {
            return nil
        }
    }
}



