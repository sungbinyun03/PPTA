//
//  NotificationService.swift
//  PPTANotificationService
//
//  Applies a coach's lock or snooze the moment its push arrives, even when PPTA is force-quit.
//
//  Why this exists: lock/unlock used to be applied only by the app — its push handler, which iOS
//  never runs for a force-quit app, or `LockReconciler` on the next launch. So a snooze did nothing
//  until the trainee opened PPTA. iOS *does* run a notification service extension for every alert
//  push marked `mutable-content`, whatever state the app is in, and this one has the Family Controls
//  entitlement, so it can raise and lift the shield itself.
//
//  What it does, per `type=lock|unlock` push:
//  - drops a push for another account, one already applied, or one older than the last applied
//    command (pushes can arrive out of order, and this process can't ask Firestore which is newest);
//  - takes `LockCommandClaim`, so the app (if it is running) doesn't apply the same command too;
//  - does the on-device half through the same code as the app (`applyLockLocally` /
//    `applyUnlockLocally`: shield, shield copy, grace window);
//  - records the status in the App Group for the app to pick up, and POSTs it to `statusUpdate`
//    with the command id, which updates Firestore, tells the coaches, and acks the command.
//
//  It never shows its own banner: the push's alert is the banner, delivered unchanged.
//
//  Firebase is linked only because the shared model files import it. Nothing here may call into
//  it (no `FirebaseApp.configure`, no Auth, no Firestore): the extension has no signed-in session.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    private var contentHandler: ((UNNotificationContent) -> Void)?
    private var content: UNNotificationContent?
    /// `deliver` can be reached from the apply task and from `serviceExtensionTimeWillExpire` on
    /// different threads; the handler must run exactly once.
    private let deliverLock = NSLock()

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        content = request.content

        let payload = request.content.userInfo
        guard let command = PushCommand(payload) else {
            deliver()
            return
        }
        Task {
            await apply(command)
            deliver()
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // The shield and grace are applied before any network wait, so running out of time only
        // costs the status POST; the app's next run and the coach's sheet recover from that.
        deliver()
    }

    private func deliver() {
        deliverLock.lock()
        let handler = contentHandler
        contentHandler = nil
        deliverLock.unlock()
        guard let handler, let content else { return }
        handler(content)
    }

    // MARK: - Command

    private struct PushCommand {
        let id: String
        let isLock: Bool
        let uid: String
        let by: String?
        let coach: String
        let message: String?
        /// Server time the push was sent.
        let at: Date

        init?(_ payload: [AnyHashable: Any]) {
            guard
                let type = payload["type"] as? String, type == "lock" || type == "unlock",
                let id = payload["cmd"] as? String, !id.isEmpty,
                let uid = payload["uid"] as? String, !uid.isEmpty,
                let atMillis = (payload["at"] as? String).flatMap(Double.init)
            else { return nil }
            self.id = id
            self.isLock = type == "lock"
            self.uid = uid
            self.by = payload["by"] as? String
            self.coach = (payload["byName"] as? String)?.firstNameOnly ?? "Your coach"
            self.message = ActionMessage.clean(payload["message"] as? String)
            self.at = Date(timeIntervalSince1970: atMillis / 1000)
        }
    }

    private func apply(_ command: PushCommand) async {
        // Signed out, or the push followed an FCM token to a different account.
        guard command.uid == LocalSettingsStore.loadCurrentUserId() else {
            print("NSE: push \(command.id) is not for the signed-in account; skipping.")
            return
        }
        // A coach command is for today only, as everywhere else.
        guard Calendar.current.isDateInToday(command.at) else { return }
        guard LocalSettingsStore.lastAppliedLockCommandId != command.id else { return }
        if let last = LocalSettingsStore.lastAppliedLockCommandAt, command.at <= last {
            print("NSE: push \(command.id) is older than the last applied command; skipping.")
            return
        }
        guard LockCommandClaim.tryClaim(command.id) else {
            print("NSE: push \(command.id) is being applied by the app.")
            return
        }

        let manager = DeviceActivityManager.shared
        var settings = LocalSettingsStore.load()
        let status: TraineeStatus
        let outcome: LockOutcome
        if command.isLock {
            // Stored first: the shield copy written inside `applyLockLocally` reads it.
            LocalSettingsStore.lockMessage = command.message
            outcome = manager.applyLockLocally(settings, coach: command.coach)
            status = .cutOff
            settings.lockedByName = command.coach
        } else {
            LocalSettingsStore.lockMessage = nil
            outcome = manager.applyUnlockLocally(settings)
            status = .snoozedLock
            settings.lockedByName = nil
        }

        // Same bookkeeping as `LockReconciler.perform`: an unlock is final whatever happened; a lock
        // that wasn't enforced (pressure Off, no apps) is left for the app to retry and ack.
        guard outcome == .applied else {
            if command.isLock {
                LocalSettingsStore.lockMessage = nil
                LockCommandClaim.release(command.id)
            } else {
                markApplied(command)
            }
            return
        }
        markApplied(command)

        // The app's copy of the status. The blob is what `LockReconciler` checks to tell an applied
        // lock from one that still needs its full path; the pending status reaches the in-memory
        // settings (and Firestore) on the app's next foreground, like the AppMonitor extension's.
        settings.traineeStatus = status
        LocalSettingsStore.save(settings)
        LocalSettingsStore.savePendingStatus(status, resetStartDate: nil, lockedByName: settings.lockedByName)

        await postStatus(status, command: command)
    }

    private func markApplied(_ command: PushCommand) {
        LocalSettingsStore.lastAppliedLockCommandId = command.id
        LocalSettingsStore.lastAppliedLockCommandAt = command.at
    }

    /// Updates Firestore, fans out to the coaches, and (via `cmd`) acks the command for the coach's
    /// sheet. Best-effort: a failure leaves the device locked/snoozed correctly, and the app acks a
    /// lock on its next run.
    private func postStatus(_ status: TraineeStatus, command: PushCommand) async {
        guard let request = DeviceActivityManager.makeStatusUpdateRequest(
            uid: command.uid, status: status, type: nil, cause: .coach, by: command.by,
            targetCoach: nil, extra: [:], cmd: command.id
        ) else { return }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            print("NSE: statusUpdate \(status.rawValue) for \(command.id): \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        } catch {
            print("NSE: statusUpdate failed:", error)
        }
    }
}
