//
//  PPTAMinimalTests.swift
//  PPTAMinimalTests
//
//  Created by Sungbin Yun on 1/12/25.
//

import Foundation
import Testing
@testable import PPTAMinimal

struct PPTAMinimalTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

}

struct LockDecisionTests {

    private let t0 = Date(timeIntervalSince1970: 1_000)
    private let t1 = Date(timeIntervalSince1970: 2_000)

    private func verdict(
        pushId: String? = "A", pushUID: String? = "me", currentUID: String? = "me",
        latestId: String? = "A", latestAt: Date? = Date(timeIntervalSince1970: 1_000),
        before: String? = nil, now: String? = nil, newest: Date? = nil
    ) -> LockDecision.PushVerdict {
        LockDecision.pushVerdict(
            pushId: pushId, pushUID: pushUID, currentUID: currentUID,
            latestId: latestId, latestAt: latestAt,
            lastAppliedBefore: before, lastAppliedNow: now, newestSeenAt: newest)
    }

    // B1
    @Test func dropsPushForAnotherAccount() {
        #expect(verdict(pushUID: "someone-else") == .drop)
    }

    @Test func noUidAndNoLockCommandIsNotAppliedBlindly() {
        #expect(verdict(pushId: nil, pushUID: nil, latestId: nil) == .drop)
        #expect(verdict(pushId: "A", pushUID: nil, latestId: nil) == .drop)
        #expect(verdict(pushId: "A", pushUID: nil, latestId: "A") == .apply)
    }

    // B2
    @Test func rereadsWhenAnotherPathAppliedACommandDuringTheRead() {
        #expect(verdict(before: "Z", now: "B") == .reconcileAgain)
    }

    @Test func rereadsWhenTheReadIsOlderThanACommandAlreadySeen() {
        #expect(verdict(latestAt: t0, newest: t1) == .reconcileAgain)
        #expect(verdict(latestAt: t1, newest: t1) == .apply)
    }

    @Test func dropsASupersededPush() {
        #expect(verdict(latestId: "B") == .drop)
    }

    // B3
    @Test func ackForANewerCurrentCommandSupersedesTheTrackedOne() {
        let r = LockDecision.ackResolution(
            trackedId: "A", trackedIssuedAt: t0, ackId: "B", ackResult: "applied",
            commandId: "B", commandAt: t1)
        #expect(r == .superseded)
    }

    @Test func staleAckForAnOlderCommandIsIgnored() {
        let r = LockDecision.ackResolution(
            trackedId: "A", trackedIssuedAt: t1, ackId: "Z", ackResult: "applied",
            commandId: "Z", commandAt: t0)
        #expect(r == .none)
    }

    @Test func ackForTheTrackedCommandResolves() {
        let r = LockDecision.ackResolution(
            trackedId: "A", trackedIssuedAt: t0, ackId: "A", ackResult: "applied",
            commandId: "A", commandAt: t0)
        #expect(r == .resolved(result: "applied"))
    }
}
