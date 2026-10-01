//
//  LockDecision.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 9/30/26.
//

import Foundation

/// The decisions `LockReconciler` and the coach's sheet make about a command, as pure functions of
/// plain values so the race handling can be tested without Firestore or a shield.
enum LockDecision {

    // MARK: - Trainee: should a lock/unlock push be applied?

    enum PushVerdict: Equatable {
        case apply
        /// Not for this user, already handled, or superseded. Does nothing and writes no ack: the
        /// command that superseded it gets its own, and a stale ack would overwrite that one.
        case drop
        /// The picture changed while the server read was in flight (another path applied a command,
        /// or the read returned something older than we've already seen). Read again and re-decide;
        /// applying on the strength of a stale read is how a lock lands after a newer release.
        case reconcileAgain
    }

    /// - Parameters:
    ///   - pushId: the push's `cmd`; nil from a server that predates `lockCommand`.
    ///   - pushUID: the push's `uid` (the account it was sent to); nil from a server that predates it.
    ///   - currentUID: the signed-in user. A token can outlive the session that registered it, so
    ///     the push's target is checked against this rather than trusted.
    ///   - latest: the server's `lockCommand` as read *after* the push arrived; nil if the read failed
    ///     or the document has none.
    ///   - lastAppliedBefore / lastAppliedNow: `lastAppliedLockCommandId` when the read started and
    ///     now that it returned.
    ///   - newestSeenAt: the newest command `at` this process has seen on any path.
    static func pushVerdict(
        pushId: String?,
        pushUID: String?,
        currentUID: String?,
        latestId: String?,
        latestAt: Date?,
        lastAppliedBefore: String?,
        lastAppliedNow: String?,
        newestSeenAt: Date?
    ) -> PushVerdict {
        guard let currentUID else { return .drop }
        if let pushUID, pushUID != currentUID { return .drop }

        if lastAppliedNow != lastAppliedBefore { return .reconcileAgain }

        // Without a target uid the push can't be tied to this account by itself. A command id that
        // is this account's own `lockCommand` does tie it; no `cmd` and no `lockCommand` doesn't,
        // and neither does a failed read, so those apply nothing (the old server never wrote a
        // lockCommand, so it is the one case this stops serving, on purpose).
        guard let pushId else {
            return (pushUID != nil || latestId != nil) ? .apply : .drop
        }
        if lastAppliedNow == pushId { return .drop }

        guard let latestId else {
            // Read failed or no lockCommand: a push the server addressed to this uid is the best
            // evidence we have; an unaddressed one is not enough.
            return pushUID != nil ? .apply : .drop
        }
        if latestId != pushId { return .drop }

        // The read says this is the newest command, but it is older than one already seen: the read
        // raced a newer write and is stale.
        if let newestSeenAt, let latestAt, latestAt < newestSeenAt { return .reconcileAgain }
        return .apply
    }

    // MARK: - Coach: has the trainee's ack resolved the command being tracked?

    enum AckResolution: Equatable {
        case none
        case resolved(result: String)
        /// A newer command, from anyone, replaced the tracked one and its ack is in. The tracked
        /// command will never be acked by id.
        case superseded
    }

    /// - Parameters:
    ///   - trackedId / trackedIssuedAt: the command the sheet is waiting on, and when this device
    ///     sent it (`issuedAt` is local, so `skew` of slack is allowed against the server's `at`).
    ///   - ackId / ackResult: the trainee's single `lockAck`.
    ///   - commandId / commandAt: the trainee's current `lockCommand`.
    static func ackResolution(
        trackedId: String,
        trackedIssuedAt: Date,
        ackId: String?,
        ackResult: String?,
        commandId: String?,
        commandAt: Date?,
        skew: TimeInterval = 30
    ) -> AckResolution {
        guard let ackId, let ackResult else { return .none }
        if ackId == trackedId { return .resolved(result: ackResult) }
        // The ack is for a different id. It only counts if it acks the *current* command and that
        // command was issued after the tracked one; an older command's late ack says nothing about
        // the tracked one.
        guard ackId == commandId, let commandAt,
              commandAt > trackedIssuedAt.addingTimeInterval(-skew) else { return .none }
        return .superseded
    }
}
