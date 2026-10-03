//
//  LockReconciler.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 9/29/26.
//

import Foundation
import FamilyControls
import FirebaseAuth
import FirebaseFirestore

/// Converges this device on the coach's most recent lock/unlock command.
///
/// A coach's lock used to reach the trainee through exactly one door: a silent FCM push, which iOS
/// never delivers to a force-quit app and throttles, defers or drops the rest of the time. One
/// dropped push meant no shield and nothing ever noticed. The fix is to make the *server* the
/// record of coach intent: `lockApp`/`unlockApp` write `userSettings/{uid}.lockCommand`
/// (`{id, action, by, byName, at}`) before they push, and this type applies that command whenever
/// the app runs — from the push itself (`applyPush`), and from a snapshot listener that fires on
/// launch, on foreground, and on the notification tap that causes either.
///
/// ### Idempotent by command id
/// Every command is applied at most once per device. `LocalSettingsStore.lastAppliedLockCommandId`
/// is the fast-path dedupe between the push and the listener, and `lockAck` (`{id, action, result,
/// at}`, written here after applying) is the durable record the coach's sheet waits on. Neither key
/// is in `UserSettings.CodingKeys`, so the trainee's full-document saves can't clobber them; both are
/// read from the raw snapshot, never through the model.
///
/// ### Lock is level-triggered, unlock is edge-triggered
/// - A **lock** that is already applied is silently re-asserted on every reconcile for the rest of
///   that day (`reapplyShield`: no banner, no status POST, no change to the shield context). That is
///   what makes Pressure Off then back on the same day re-lock, and what survives anything else that
///   knocked the shield down.
/// - An **unlock** is acted on once. Re-running one would re-arm the grace window and re-announce the
///   snooze, so an acked or locally-applied unlock is never touched again. There is no "is a grace
///   period running" veto: it isn't needed (a snooze is the *latest* command, so no lock re-asserts
///   over it), and the grace activity stays armed for ~24h, which as a veto blinded every re-lock.
///
/// ### Commands are for today only
/// A coach lock is "for today", matching the extension clearing the shield at `intervalDidEnd`. A
/// command whose `at` is not in the device's current day is ignored.
///
/// ### The ways this can fail open, and what stops each
/// - *A failed read must never read as "no lock".* An error, a missing document, an undecodable
///   `lockCommand` or selection, or an empty selection each do nothing. An empty selection would make
///   `ShieldPolicy.apply` write nil/nil, which clears.
/// - *A stale cache must not decide.* Only server-confirmed snapshots are acted on, so a cached
///   lock can't be applied a moment before the real unlock arrives.
/// - *A late unlock must not lift a later shield.* An unlock is skipped if something raised a shield
///   after it (`ShieldPolicy.lastRaisedAt`: a Hardcore cutoff or an expired snooze), so a Release whose
///   push was dropped can't unlock a limit-based shield hours afterwards. The push path is live and
///   doesn't need this.
/// - *A late lock push must not beat a newer unlock.* The push path asks the server for the latest
///   command first and drops a superseded one, and if another path applied something while it was
///   reading (or the read is older than a command already seen) it reads again rather than act.
/// - *A push must be for this account.* It carries the target `uid`; one for anyone else is dropped,
///   and one with no `uid` is applied only when the account's own `lockCommand` vouches for it.
///   The decisions are in `LockDecision`.
/// - *A stale ack must not replace the real one.* `lockAck` is one field; acks are written in a
///   transaction that skips when a newer command exists, and superseded pushes write none.
/// - Hardcore and snooze-ended shields are never cleared or re-attributed by anything here: the only
///   clear is `handleRemoteUnlock` for an unlock command that passed the checks above.
@MainActor
final class LockReconciler {
    static let shared = LockReconciler()
    private init() {}

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    /// UID the current listener is attached to, so a session change re-attaches rather than
    /// keeping a listener on the previous user's document.
    private var listeningUID: String?

    /// Command ids being applied right now. `handleRemoteLock/Unlock` suspend while their network
    /// writes resolve, so without this a push and the listener's first snapshot could both start the
    /// same command before either has recorded it as applied.
    private var inFlight: Set<String> = []

    // MARK: - Types

    struct Command {
        enum Action: String { case lock, unlock }

        let id: String
        let action: Action
        let by: String?
        let byName: String?
        /// Server time. Nil for a command taken from a push payload, which is live by definition.
        let at: Date?
        /// The coach's optional note, already cleaned (`ActionMessage.clean`). Display only: it never
        /// takes part in any apply/ack decision.
        let message: String?

        init(id: String, action: Action, by: String?, byName: String?, at: Date?, message: String? = nil) {
            self.id = id
            self.action = action
            self.by = by
            self.byName = byName
            self.at = at
            self.message = ActionMessage.clean(message)
        }

        init?(_ raw: Any?) {
            guard
                let dict = raw as? [String: Any],
                let id = dict["id"] as? String, !id.isEmpty,
                let actionRaw = dict["action"] as? String,
                let action = Action(rawValue: actionRaw)
            else { return nil }
            self.init(
                id: id,
                action: action,
                by: dict["by"] as? String,
                byName: dict["byName"] as? String,
                at: (dict["at"] as? Timestamp)?.dateValue(),
                message: dict["message"] as? String
            )
        }
    }

    private struct Ack {
        let id: String
        let result: String

        init?(_ raw: Any?) {
            guard
                let dict = raw as? [String: Any],
                let id = dict["id"] as? String,
                let result = dict["result"] as? String
            else { return nil }
            self.id = id
            self.result = result
        }
    }

    // MARK: - Lifecycle

    /// Attaches the listener for the signed-in user; its first server snapshot is the
    /// launch / foreground reconciliation.
    ///
    /// Idempotent: called from both `HomeView.onAppear` (launch, and a sign-in mid-session, which
    /// `scenePhase` doesn't see) and the app's `scenePhase == .active` block (foreground).
    func start() {
        guard let uid = Auth.auth().currentUser?.uid else { stop(); return }
        if listener != nil, listeningUID == uid { return }
        stop()

        listeningUID = uid
        // Metadata changes on, so the server-confirmed snapshot still arrives after a cache one
        // that carried the same data (which would otherwise be the only callback).
        listener = db.collection("userSettings").document(uid)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    self?.handle(snapshot, error: error)
                }
            }
        print("LockReconciler: listening to userSettings/\(uid).")
    }

    /// Detaches on background. Nothing should be listening while the app is suspended — the push
    /// handler and the AppMonitor extension cover that window.
    func stop() {
        listener?.remove()
        listener = nil
        listeningUID = nil
    }

    // MARK: - Push

    /// Applies a `type=lock|unlock` push, once it is known to be for the signed-in user and still
    /// the newest command (`LockDecision.pushVerdict`). A push with no `cmd` (a server that predates
    /// `lockCommand`) applies and finishes with no ack, but only if the account has a `lockCommand`
    /// or the push names this uid.
    func applyPush(_ payload: [AnyHashable: Any], pushShowsBanner: Bool) async {
        let isLock = (payload["type"] as? String) == "lock"
        let byName = payload["byName"] as? String
        let by = payload["by"] as? String
        let pushUID = payload["uid"] as? String
        let id = (payload["cmd"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        let pushMessage = ActionMessage.clean(payload["message"] as? String)

        // The FCM token outlives the session that registered it, so a push can reach whoever is
        // signed in now. It carries the account it was sent to; anything else is not ours to apply.
        if let pushUID, pushUID != Auth.auth().currentUser?.uid {
            print("LockReconciler: push is for another account; dropping.")
            return
        }

        if let id {
            guard LocalSettingsStore.lastAppliedLockCommandId != id, !inFlight.contains(id) else {
                print("LockReconciler: push for command \(id) already handled.")
                return
            }
            inFlight.insert(id)
        }
        defer { if let id { inFlight.remove(id) } }

        // Pushes can arrive out of order, and the read below can itself be stale: a lock push can
        // fetch "latest = this lock" a moment before a release lands and is applied by the listener.
        // So decide, and if anything moved while we were reading, read and decide again. After the
        // last attempt we apply nothing; the listener converges on the newest command.
        for _ in 0..<3 {
            let appliedBefore = LocalSettingsStore.lastAppliedLockCommandId
            let latest = await fetchLatestCommand()
            if let at = latest?.at { noteSeen(at) }

            let verdict = LockDecision.pushVerdict(
                pushId: id,
                pushUID: pushUID,
                currentUID: Auth.auth().currentUser?.uid,
                latestId: latest?.id,
                latestAt: latest?.at,
                lastAppliedBefore: appliedBefore,
                lastAppliedNow: LocalSettingsStore.lastAppliedLockCommandId,
                newestSeenAt: newestSeenAt
            )
            switch verdict {
            case .drop:
                print("LockReconciler: push \(id ?? "(no cmd)") not applied (not ours, handled, or superseded).")
                return
            case .reconcileAgain:
                print("LockReconciler: push \(id ?? "(no cmd)"): state moved during the read; re-checking.")
                continue
            case .apply:
                guard let id else {
                    let coach = byName?.firstNameOnly ?? "Your coach"
                    if isLock {
                        LocalSettingsStore.lockMessage = pushMessage
                        await DeviceActivityManager.shared.handleRemoteLock(from: coach, coachUID: by, pushShowsBanner: pushShowsBanner, message: pushMessage)
                    } else {
                        LocalSettingsStore.lockMessage = nil
                        await DeviceActivityManager.shared.handleRemoteUnlock(from: coach, coachUID: by, pushShowsBanner: pushShowsBanner)
                    }
                    return
                }
                // The durable copy wins when it is this command; the push payload is the fallback.
                let message = latest?.id == id ? latest?.message : pushMessage
                let command = Command(id: id, action: isLock ? .lock : .unlock, by: by, byName: byName, at: latest?.at, message: message)
                await perform(command, existingAck: nil, pushShowsBanner: pushShowsBanner)
                return
            }
        }
        print("LockReconciler: push \(id ?? "(no cmd)") kept moving; leaving it to the listener.")
    }

    /// Newest command `at` seen on any path, so a read that returns an older command than one
    /// already seen is recognised as stale.
    private var newestSeenAt: Date?

    private func noteSeen(_ at: Date) {
        if newestSeenAt.map({ at > $0 }) ?? true { newestSeenAt = at }
    }

    // MARK: - Listener

    private func handle(_ snapshot: DocumentSnapshot?, error: Error?) {
        // A snapshot that arrives after sign-out (or for a previous user) must not act, and takes
        // the listener down with it.
        guard let uid = Auth.auth().currentUser?.uid, uid == listeningUID else {
            stop()
            return
        }
        // Offline, permission-denied, or a missing document: leave local state exactly as it is.
        // "The read failed" must never fall through to "there is no lock".
        if let error {
            print("LockReconciler: snapshot failed, leaving shield state alone:", error)
            return
        }
        guard let snapshot, snapshot.exists, let data = snapshot.data() else {
            print("LockReconciler: no userSettings document; leaving shield state alone.")
            return
        }
        // Cached data may predate the latest command. Wait for the server-confirmed snapshot.
        guard !snapshot.metadata.isFromCache else { return }
        guard let command = Command(data["lockCommand"]) else { return }
        if let at = command.at { noteSeen(at) }

        Task { @MainActor in
            await reconcile(command, ack: Ack(data["lockAck"]), snapshot: snapshot)
        }
    }

    private func reconcile(_ command: Command, ack: Ack?, snapshot: DocumentSnapshot) async {
        guard let at = command.at, Calendar.current.isDateInToday(at) else { return }
        guard !inFlight.contains(command.id) else { return }

        let appliedLocally = LocalSettingsStore.lastAppliedLockCommandId == command.id
        let ackedForThis = ack?.id == command.id

        switch command.action {
        case .lock:
            // An ack that isn't "applied" (pressure was Off, no apps) is not an enforced lock, so
            // the command is retried now that settings may have changed.
            let applied = appliedLocally || (ackedForThis && ack?.result == LockOutcome.applied.rawValue)
            guard applied else {
                inFlight.insert(command.id)
                defer { inFlight.remove(command.id) }
                await perform(command, existingAck: ack, pushShowsBanner: false)
                return
            }

            // Already applied: re-assert silently. Everything that can make this a no-op fails
            // closed (see the type comment).
            let remote: UserSettings
            do {
                remote = try snapshot.data(as: UserSettings.self)
            } catch {
                print("LockReconciler: failed to decode UserSettings, leaving shield state alone:", error)
                return
            }
            guard remote.isTracking else { return }
            let selection = remote.applications
            guard !selection.applicationTokens.isEmpty || !selection.categoryTokens.isEmpty else {
                print("LockReconciler: remote selection is empty; leaving shield state alone.")
                return
            }

            // Pressure toggled Off and back On wiped the status to allClear while the lock stood.
            // Run the full path again so Home, the coaches and the shield agree. Idempotent: it
            // leaves the status at .cutOff, so the next reconcile takes the silent branch.
            if LocalSettingsStore.load().traineeStatus != .cutOff {
                inFlight.insert(command.id)
                defer { inFlight.remove(command.id) }
                await perform(command, existingAck: ack, pushShowsBanner: false)
            } else {
                DeviceActivityManager.shared.reapplyShield(matching: selection)
            }

        case .unlock:
            guard !appliedLocally, !ackedForThis else { return }

            inFlight.insert(command.id)
            defer { inFlight.remove(command.id) }

            // Something raised a shield after this release (30s of slack for clock skew between
            // the server's `at` and this device's stamp): lifting now would clear that one.
            if let raised = ShieldPolicy.lastRaisedAt, raised > at.addingTimeInterval(30) {
                print("LockReconciler: unlock \(command.id) predates a later shield; not clearing.")
                LocalSettingsStore.lastAppliedLockCommandId = command.id
                await writeAck(command, result: "superseded")
                return
            }
            await perform(command, existingAck: ack, pushShowsBanner: false)
        }
    }

    // MARK: - Apply + ack

    /// Runs the command through the existing event path (`handleRemoteLock` / `handleRemoteUnlock`:
    /// shield, banner, status write, coach fan-out, grace), records it, and acks it. Callers hold
    /// `inFlight` for `command.id`.
    private func perform(_ command: Command, existingAck: Ack?, pushShowsBanner: Bool) async {
        let coach = command.byName?.firstNameOnly ?? "Your coach"
        let outcome: LockOutcome
        switch command.action {
        case .lock:
            // Stored before the lock runs: the status write inside it is what refreshes Home and the
            // shield context, and both read this.
            LocalSettingsStore.lockMessage = command.message
            outcome = await DeviceActivityManager.shared.handleRemoteLock(
                from: coach, coachUID: command.by, pushShowsBanner: pushShowsBanner, message: command.message)
            if outcome != .applied { LocalSettingsStore.lockMessage = nil }
        case .unlock:
            LocalSettingsStore.lockMessage = nil
            outcome = await DeviceActivityManager.shared.handleRemoteUnlock(
                from: coach, coachUID: command.by, pushShowsBanner: pushShowsBanner)
        }

        // An unlock is final whatever happened (re-running it would re-arm grace). A lock that
        // wasn't enforced stays open, so a later reconcile can retry it.
        if outcome == .applied || command.action == .unlock {
            LocalSettingsStore.lastAppliedLockCommandId = command.id
        }

        // Never downgrade an "applied" ack, and don't rewrite an identical one.
        if let existingAck, existingAck.id == command.id,
           existingAck.result == LockOutcome.applied.rawValue || existingAck.result == outcome.rawValue {
            return
        }
        await writeAck(command, result: outcome.rawValue)
    }

    /// Targeted update, not `UserSettingsManager.update {}`: that restarts from the App Group
    /// blob and rewrites the whole document, which must not carry a stale copy of anything.
    ///
    /// `lockAck` is a single field, so a late ack for an older command would erase the real ack for
    /// the newest one and leave the coach waiting. The write is a transaction that re-reads the
    /// document and skips if its `lockCommand` is no longer this command.
    private func writeAck(_ command: Command, result: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let ref = db.collection("userSettings").document(uid)
        let ackFields: [String: Any] = [
            "id": command.id,
            "action": command.action.rawValue,
            "result": result,
            "at": FieldValue.serverTimestamp(),
        ]
        do {
            let wrote = try await db.runTransaction { transaction, errorPointer -> Any? in
                let snapshot: DocumentSnapshot
                do {
                    snapshot = try transaction.getDocument(ref)
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
                if let current = Command(snapshot.data()?["lockCommand"]), current.id != command.id {
                    return false
                }
                transaction.updateData(["lockAck": ackFields], forDocument: ref)
                return true
            }
            if (wrote as? Bool) == true {
                print("LockReconciler: acked \(command.action.rawValue) \(command.id): \(result).")
            } else {
                print("LockReconciler: ack for \(command.id) skipped; a newer command exists.")
            }
        } catch {
            print("LockReconciler: failed to write lockAck:", error)
        }
    }

    /// The server's current `lockCommand`, or nil if it can't be read within `timeout`.
    private func fetchLatestCommand(timeout: TimeInterval = 4) async -> Command? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        let ref = db.collection("userSettings").document(uid)
        return await withCheckedContinuation { continuation in
            var done = false
            let finish: (Command?) -> Void = { value in
                guard !done else { return }
                done = true
                continuation.resume(returning: value)
            }
            ref.getDocument(source: .server) { snapshot, _ in
                finish(Command(snapshot?.data()?["lockCommand"]))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { finish(nil) }
        }
    }
}
