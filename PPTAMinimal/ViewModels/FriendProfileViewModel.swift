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

    /// Display/stat fields a caller can hand over up front (e.g. from a `StatusCenterPerson`
    /// or `User` it already has in memory), so the sheet renders instantly instead of
    /// showing a blank "Loading..." screen while `refresh()` is in flight.
    struct Snapshot {
        var name: String? = nil
        var profilePicUrl: String? = nil
        var isCoach: Bool? = nil
        var isTrainee: Bool? = nil
        var traineeStatus: TraineeStatus? = nil
        var streakDays: Int? = nil
        var timeLimitMinutes: Int? = nil
        var pressureLevel: PressureLevel? = nil
        var lockedByName: String? = nil
    }

    @Published var isLoading = false
    @Published var errorMessage: String?
    /// True once `refresh()` has completed successfully at least once.
    @Published var hasLoadedOnce = false

    @Published var name: String = ""
    @Published var profilePicUrl: String? = nil

    // Other user's tracking state (from their UserSettings)
    @Published var traineeStatus: TraineeStatus = .noStatus
    @Published var streakDays: Int = 0
    @Published var timeLimitMinutes: Int = 0
    @Published var pressureLevel: PressureLevel = PressureLevel.off

    // Relationship relative to current user
    @Published var isCoach: Bool = false     // other is my coach
    @Published var isTrainee: Bool = false   // other is my trainee
    @Published var friendshipStatus: FriendProfileStatus = .notFriend

    @Published var coachAction = ActionConfig(title: "Request as Coach", enabled: false)
    @Published var traineeAction = ActionConfig(title: "Request as Trainee", enabled: false)

    @Published var isPerformingLockUnlock = false
    @Published var lockUnlockError: String?
    @Published var lockedByName: String? = nil

    private let otherUserId: String

    private let usersRepo = UserRepository()
    private let settingsRepo = UserSettingsRepository()
    private let friendships = FriendshipRepository()
    private let roleRequests = RoleRequestRepository()

    /// Pending role requests from the last successful `refresh()`, reused by the action
    /// helpers below so a button tap doesn't re-fetch what `refresh()` just fetched.
    private var incomingPending: [RoleRequest] = []
    private var outgoingPending: [RoleRequest] = []

    private var myUid: String? { Auth.auth().currentUser?.uid }

    init(otherUserId: String, snapshot: Snapshot = Snapshot()) {
        self.otherUserId = otherUserId
        if let name = snapshot.name { self.name = name }
        if let profilePicUrl = snapshot.profilePicUrl { self.profilePicUrl = profilePicUrl }
        if let isCoach = snapshot.isCoach { self.isCoach = isCoach }
        if let isTrainee = snapshot.isTrainee { self.isTrainee = isTrainee }
        if let traineeStatus = snapshot.traineeStatus { self.traineeStatus = traineeStatus }
        if let streakDays = snapshot.streakDays { self.streakDays = streakDays }
        if let timeLimitMinutes = snapshot.timeLimitMinutes { self.timeLimitMinutes = timeLimitMinutes }
        if let pressureLevel = snapshot.pressureLevel { self.pressureLevel = pressureLevel }
        self.lockedByName = snapshot.lockedByName
    }

    /// Fetches everything the sheet needs. All six reads are independent of each other,
    /// so they run concurrently — this is one round trip's worth of latency instead of six.
    func refresh() async {
        guard let uid = myUid else { return }
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        do {
            async let otherUserTask = usersRepo.fetchUser(by: otherUserId)
            async let otherSettingsTask = settingsRepo.fetchSettings(for: otherUserId)
            async let mySettingsTask = settingsRepo.fetchSettings(for: uid)
            async let friendsTask = friendships.areFriends(uid, otherUserId)
            async let incomingTask = roleRequests.fetchIncomingPending(for: uid)
            async let outgoingTask = roleRequests.fetchOutgoingPending(for: uid)

            let (otherUser, otherSettings, mySettingsOpt, friends, incoming, outgoing) =
                try await (otherUserTask, otherSettingsTask, mySettingsTask, friendsTask, incomingTask, outgoingTask)
            let mySettings = mySettingsOpt ?? UserSettings()

            if let otherUser {
                name = otherUser.name
            } else if name.isEmpty {
                name = "Unknown"
            }
            profilePicUrl = otherSettings?.profileImageURL?.absoluteString

            // Snapshot the other user's stats for display.
            if let otherSettings {
                pressureLevel = otherSettings.pressureLevel
                timeLimitMinutes = otherSettings.thresholdHour * 60 + otherSettings.thresholdMinutes
                streakDays = StreakCalculator.daysSince(start: otherSettings.startDailyStreakDate, calendar: .current)
                traineeStatus = otherSettings.isTracking ? otherSettings.traineeStatus : .noStatus
            } else {
                pressureLevel = PressureLevel.off
                timeLimitMinutes = 0
                streakDays = 0
                traineeStatus = .noStatus
            }

            lockedByName = otherSettings?.lockedByName

            // Friends-only policy (client-side gating; server enforces too)
            friendshipStatus = friends ? .isFriend : .notFriend

            // Determine role relationship from my uid-based arrays
            isCoach = mySettings.coachIds.contains(otherUserId)
            isTrainee = mySettings.traineeIds.contains(otherUserId)

            incomingPending = incoming
            outgoingPending = outgoing

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

            hasLoadedOnce = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Lock / Unlock actions

    func performLock(url: URL) async {
        guard await performLockUnlockAction(url: url) else { return }
        // Optimistic update: show the coach the expected state immediately while
        // the FCM travels to the trainee's device. After 15s we verify against
        // Firestore — if the FCM was lost, the real status reappears and the
        // coach can try locking again.
        traineeStatus = .cutOff
        scheduleVerification(
            expected: .cutOff,
            failureTitle: "Lock may not have reached \(name)",
            failureBody: "\(name) may still have access to their apps. Try locking them again."
        )
    }

    func performUnlock(url: URL) async {
        guard await performLockUnlockAction(url: url) else { return }
        traineeStatus = .snoozedLock
        scheduleVerification(
            expected: .snoozedLock,
            failureTitle: "Snooze may not have reached \(name)",
            failureBody: "The snooze unlock didn't seem to go through. Try again."
        )
    }

    /// Verifies the action landed by re-fetching Firestore after a delay.
    /// If the status didn't update to `expected`, reverts the UI and fires an iOS
    /// system notification so the coach is alerted even if they've left the app.
    private func scheduleVerification(expected: TraineeStatus, failureTitle: String, failureBody: String) {
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            await refresh()
            if traineeStatus != expected {
                NotificationManager.shared.sendNotification(title: failureTitle, body: failureBody)
            }
        }
    }

    /// Calls the signed Cloud Run URL and returns `true` on HTTP 2xx.
    @discardableResult
    private func performLockUnlockAction(url: URL) async -> Bool {
        isPerformingLockUnlock = true
        lockUnlockError = nil
        defer { isPerformingLockUnlock = false }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 15
            let (_, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lockUnlockError = "Action failed — please try again."
                return false
            }
            return true
        } catch {
            lockUnlockError = error.localizedDescription
            return false
        }
    }

    // MARK: - Actions

    func performCoachPrimary() async {
        guard myUid != nil else { return }
        do {
            // other is my coach
            if isCoach {
                // current user is trainee of other
                try await roleRequests.removeRelationship(otherId: otherUserId, role: .trainee)
            } else {
                // If there is an incoming request that would make other my coach, accept it.
                if let incomingId = findIncomingIdForOtherBecomingMyCoach() {
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
        guard myUid != nil else { return }
        do {
            // Decline incoming request (other wants to coach me) OR cancel outgoing (I requested to be trainee).
            if let incomingId = findIncomingIdForOtherBecomingMyCoach() {
                try await roleRequests.decline(id: incomingId)
            } else if let outgoingId = findOutgoingIdForMeBecomingTrainee() {
                try await roleRequests.cancel(id: outgoingId)
            }
            await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performTraineePrimary() async {
        guard myUid != nil else { return }
        do {
            // other is my trainee (I coach other)
            if isTrainee {
                try await roleRequests.removeRelationship(otherId: otherUserId, role: .coach)
            } else {
                if let incomingId = findIncomingIdForOtherBecomingMyTrainee() {
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
        guard myUid != nil else { return }
        do {
            if let incomingId = findIncomingIdForOtherBecomingMyTrainee() {
                try await roleRequests.decline(id: incomingId)
            } else if let outgoingId = findOutgoingIdForMeCoachingOther() {
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
    // Reuse the arrays fetched by the last `refresh()` instead of re-querying Firestore.

    private func findIncomingIdForOtherBecomingMyCoach() -> String? {
        incomingPending.first(where: { $0.requesterId == otherUserId && $0.role == .coach })?.id
    }

    private func findIncomingIdForOtherBecomingMyTrainee() -> String? {
        incomingPending.first(where: { $0.requesterId == otherUserId && $0.role == .trainee })?.id
    }

    private func findOutgoingIdForMeBecomingTrainee() -> String? {
        outgoingPending.first(where: { $0.targetId == otherUserId && $0.role == .trainee })?.id
    }

    private func findOutgoingIdForMeCoachingOther() -> String? {
        outgoingPending.first(where: { $0.targetId == otherUserId && $0.role == .coach })?.id
    }
}



