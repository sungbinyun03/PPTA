//
//  FriendProfileViewModel.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

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
        var isRequestingSnoozeFromMe: Bool? = nil
        var monitoredAppNames: [String]? = nil
    }

    /// Apps this person is monitoring. Empty when the shield hasn't learned any names yet.
    @Published var monitoredAppNames: [String] = []

    /// Per-app block counts over the trailing 30 days, sorted most-blocked first.
    @Published var monitoredAppStats: [MonitoredAppStat] = []

    /// (Coach side) True when this trainee, while cut off, has asked **me** to snooze their lock —
    /// my UID is in their `snoozeRequestedCoachIds`. The UI additionally gates on
    /// `traineeStatus == .cutOff`. Cleared server-side on any non-cutOff status.
    @Published var isRequestingSnoozeFromMe = false

    /// (Coach side) The note that came with the trainee's request to me, read from the live
    /// listener's raw dict. Not in the `UserSettings` Codable, so a full-doc save can't clobber it.
    @Published private(set) var snoozeRequestMessage: String?

    /// (Trainee side) True when *I* am currently cut off — used to offer the "Request to snooze"
    /// button on this person's profile when they're my coach.
    @Published var iAmCutOff = false

    /// (Trainee side) True when I've already asked **this** coach to snooze — my own
    /// `snoozeRequestedCoachIds` contains their UID. Drives the button's "Requested" state.
    @Published var iHaveRequestedSnoozeFromThem = false

    /// Sends a per-coach snooze request to this person (my coach) and optimistically flips the
    /// button to "Requested". The server arrayUnions this coach onto my settings and pushes only
    /// to them; the next `refresh()` reads that back. We only flip the local `@Published` here —
    /// no `UserSettingsManager` save, which would do a full-doc write and could clobber
    /// server-set fields like `lockedByName`. `message` is an optional note for the coach; nil or
    /// empty sends exactly what a request without a note always did.
    func requestSnooze(message: String? = nil) {
        guard let uid = myUid, !iHaveRequestedSnoozeFromThem else { return }
        DeviceActivityManager.shared.sendMercyRequest(uid: uid, targetCoach: otherUserId, message: message)
        iHaveRequestedSnoozeFromThem = true
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

    @Published var isUnfriending = false
    /// Flips to true once the unfriend call succeeds, so the sheet can dismiss itself.
    @Published var didUnfriend = false

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
        if let isRequestingSnoozeFromMe = snapshot.isRequestingSnoozeFromMe { self.isRequestingSnoozeFromMe = isRequestingSnoozeFromMe }
        if let monitoredAppNames = snapshot.monitoredAppNames { self.monitoredAppNames = monitoredAppNames }
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
            monitoredAppNames = otherSettings?.monitoredAppNames ?? []
            monitoredAppStats = otherSettings?.monitoredAppStats ?? []

            // Coach side: has this trainee asked *me* to snooze? Only when I coach them; the view
            // also gates on `traineeStatus == .cutOff`, so a stale entry never shows.
            if mySettings.traineeIds.contains(otherUserId) {
                isRequestingSnoozeFromMe = (otherSettings?.snoozeRequestedCoachIds ?? []).contains(uid)
            } else {
                isRequestingSnoozeFromMe = false
            }

            // Trainee side: am I cut off, and have I already asked *this* coach (this person)?
            iAmCutOff = mySettings.isTracking && mySettings.traineeStatus == .cutOff
            iHaveRequestedSnoozeFromThem = mySettings.snoozeRequestedCoachIds.contains(otherUserId)

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

    /// Where the last Lock / Release the coach sent has got to. Driven by the trainee's `lockAck`,
    /// not a timer: the server records the command before it pushes, and the trainee's phone acks
    /// it once it has applied it, whenever that is (push, app open, back online).
    enum LockDelivery: Equatable {
        /// Sent; the trainee's phone hasn't acked yet.
        case waiting(isLock: Bool)
        /// Still no ack after a minute. Neutral: it applies as soon as the phone is online or PPTA
        /// opens, and the listener below keeps running, so a late ack still resolves this.
        case stalled(isLock: Bool)
        case confirmed(isLock: Bool)
        /// Acked, but not enforced: pressure Off, no apps selected, or superseded by a newer command.
        case notEnforced(isLock: Bool, result: String)
    }

    @Published private(set) var lockDelivery: LockDelivery?

    /// Today's latest command is a lock / a release the trainee's phone hasn't acked. Lets the
    /// sheet offer Release for a lock still in flight, and Lock to take back a release still in flight.
    @Published private(set) var hasPendingLock = false
    @Published private(set) var hasPendingUnlock = false

    private var lockWatcher: ListenerRegistration?
    private var trackedCommand: (id: String, isLock: Bool, issuedAt: Date)?
    private var latestAck: (id: String, result: String)?
    private var latestCommand: (id: String, at: Date?)?
    private var stallTask: Task<Void, Never>?

    /// How long to wait for an ack before saying so. Not a failure threshold.
    private static let ackStallSeconds: UInt64 = 60

    /// Listens to the trainee's `userSettings` for `lockCommand` / `lockAck` while the sheet is open.
    func startWatchingLockState() {
        guard lockWatcher == nil else { return }
        lockWatcher = Firestore.firestore().collection("userSettings").document(otherUserId)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let data = snapshot?.data() else { return }
                Task { @MainActor in self?.applyLockState(data) }
            }
    }

    func stopWatchingLockState() {
        lockWatcher?.remove()
        lockWatcher = nil
        stallTask?.cancel()
    }

    private func applyLockState(_ data: [String: Any]) {
        snoozeRequestMessage = ActionMessage.snoozeRequestMessage(from: data, coachUID: myUid)

        if let ack = data["lockAck"] as? [String: Any],
           let id = ack["id"] as? String, let result = ack["result"] as? String {
            latestAck = (id, result)
        } else {
            latestAck = nil
        }

        if let cmd = data["lockCommand"] as? [String: Any], let id = cmd["id"] as? String {
            latestCommand = (id, (cmd["at"] as? Timestamp)?.dateValue())
        } else {
            latestCommand = nil
        }

        var pendingLock = false
        var pendingUnlock = false
        if let cmd = data["lockCommand"] as? [String: Any],
           let id = cmd["id"] as? String, let action = cmd["action"] as? String,
           let at = (cmd["at"] as? Timestamp)?.dateValue(),
           Calendar.current.isDateInToday(at),
           latestAck?.id != id {
            pendingLock = action == "lock"
            pendingUnlock = action == "unlock"
        }
        hasPendingLock = pendingLock
        hasPendingUnlock = pendingUnlock

        resolveTrackedCommand()
    }

    private func resolveTrackedCommand() {
        guard let tracked = trackedCommand else { return }
        // The ack is a single field, so it names whichever command the trainee acked last. If that
        // is a newer command than the one tracked, the tracked one was replaced and won't be acked.
        switch LockDecision.ackResolution(
            trackedId: tracked.id,
            trackedIssuedAt: tracked.issuedAt,
            ackId: latestAck?.id,
            ackResult: latestAck?.result,
            commandId: latestCommand?.id,
            commandAt: latestCommand?.at
        ) {
        case .none:
            return
        case .resolved(let result):
            trackedCommand = nil
            stallTask?.cancel()
            if result == "applied" {
                lockDelivery = .confirmed(isLock: tracked.isLock)
                traineeStatus = tracked.isLock ? .cutOff : .snoozedLock
            } else {
                lockDelivery = .notEnforced(isLock: tracked.isLock, result: result)
                // The optimistic status was wrong; show what the trainee's document really says.
                Task { await refresh() }
            }
        case .superseded:
            trackedCommand = nil
            stallTask?.cancel()
            lockDelivery = .notEnforced(isLock: tracked.isLock, result: "superseded")
            Task { await refresh() }
        }
    }

    private func track(command id: String, isLock: Bool) {
        trackedCommand = (id, isLock, Date())
        lockDelivery = .waiting(isLock: isLock)
        stallTask?.cancel()
        stallTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: Self.ackStallSeconds * 1_000_000_000)
            guard !Task.isCancelled, let self, self.trackedCommand?.id == id else { return }
            self.lockDelivery = .stalled(isLock: isLock)
        }
        resolveTrackedCommand()
    }

    func performLock(url: URL) async {
        let result = await performLockUnlockAction(url: url)
        guard result.ok else { return }
        // Optimistic: the coach sees the expected state straight away, and the Release button.
        traineeStatus = .cutOff
        if let cmd = result.cmd {
            track(command: cmd, isLock: true)
        } else {
            scheduleVerification(
                expected: .cutOff,
                failureTitle: "Lock not confirmed for \(name.firstNameOnly) yet",
                failureBody: "\(name.firstNameOnly)'s phone hasn't confirmed the lock."
            )
        }
    }

    func performUnlock(url: URL) async {
        let result = await performLockUnlockAction(url: url)
        guard result.ok else { return }
        traineeStatus = .snoozedLock
        // The server clears their pending requests with the grant; show it without waiting.
        isRequestingSnoozeFromMe = false
        if let cmd = result.cmd {
            track(command: cmd, isLock: false)
        } else {
            scheduleVerification(
                expected: .snoozedLock,
                failureTitle: "Snooze not confirmed for \(name.firstNameOnly) yet",
                failureBody: "\(name.firstNameOnly)'s phone hasn't confirmed the snooze."
            )
        }
    }

    /// Old-server fallback, used only when the response carries no `cmd` (before `lockApp` /
    /// `unlockApp` return the command id, so there is no ack to wait for): re-fetch after a delay
    /// and tell the coach if the status hasn't moved. Delete once the new server is deployed.
    private func scheduleVerification(expected: TraineeStatus, failureTitle: String, failureBody: String) {
        Task {
            try? await Task.sleep(nanoseconds: 15_000_000_000) // 15 seconds
            await refresh()
            if traineeStatus != expected {
                NotificationManager.shared.sendNotification(title: failureTitle, body: failureBody)
            }
        }
    }

    /// Calls the signed Cloud Run URL. `ok` is true on HTTP 2xx; `cmd` is the command id the server
    /// recorded, nil from a server that predates `lockCommand` (it answers with plain text).
    private func performLockUnlockAction(url: URL) async -> (ok: Bool, cmd: String?) {
        isPerformingLockUnlock = true
        lockUnlockError = nil
        defer { isPerformingLockUnlock = false }
        do {
            var req = URLRequest(url: url)
            req.httpMethod = "GET"
            req.timeoutInterval = 15
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                lockUnlockError = "Action failed — please try again."
                return (false, nil)
            }
            let cmd = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["cmd"] as? String
            return (true, cmd)
        } catch {
            lockUnlockError = error.localizedDescription
            return (false, nil)
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

    /// Ends the friendship and every coach/trainee tie that hangs off it. The server does the
    /// cascade; on success the sheet dismisses rather than refreshing, since there is no longer
    /// a relationship to show.
    func unfriend() async {
        guard myUid != nil else { return }
        isUnfriending = true
        defer { isUnfriending = false }
        errorMessage = nil
        do {
            try await friendships.unfriend(otherId: otherUserId)
            didUnfriend = true
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

        // Outgoing: I want to be trainee of other => role=trainee, target=other.
        // No Cancel here — cancellation lives on the Friends-tab "Pending" row now.
        if outgoing.contains(where: { $0.requesterId == myUid && $0.role == .trainee }) {
            return .init(title: "Sent", enabled: false)
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

        // Outgoing: I want to coach other => role=coach, target=other.
        // No Cancel here — cancellation lives on the Friends-tab "Pending" row now.
        if outgoing.contains(where: { $0.requesterId == myUid && $0.role == .coach }) {
            return .init(title: "Sent", enabled: false)
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



