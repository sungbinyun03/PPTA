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

struct LimitFireGateTests {

    private let day = "2026-09-30"

    @Test func reachedActsOnceAPerDayForTheSameLimitAndPressure() {
        let first = LimitFireGate.nextReachedMarker(stored: nil, day: day, limitMinutes: 5, pressure: "Hardcore")
        #expect(first != nil)
        // A relaunch / re-save re-fires the event: dropped, so no re-lock after a Release.
        #expect(LimitFireGate.nextReachedMarker(stored: first, day: day, limitMinutes: 5, pressure: "Hardcore") == nil)
    }

    @Test func reachedActsAgainOnANewDay() {
        let yesterday = LimitFireGate.nextReachedMarker(stored: nil, day: "2026-09-29", limitMinutes: 5, pressure: "Hardcore")
        #expect(LimitFireGate.nextReachedMarker(stored: yesterday, day: day, limitMinutes: 5, pressure: "Hardcore") != nil)
    }

    @Test func reachedActsAgainWhenTheLimitOrPressureIsChanged() {
        let m = LimitFireGate.nextReachedMarker(stored: nil, day: day, limitMinutes: 30, pressure: "Standard")
        #expect(LimitFireGate.nextReachedMarker(stored: m, day: day, limitMinutes: 5, pressure: "Standard") != nil)
        #expect(LimitFireGate.nextReachedMarker(stored: m, day: day, limitMinutes: 30, pressure: "Hardcore") != nil)
    }

    @Test func warningsOnlyFireAboveTheHighestAlreadyFired() {
        let m = LimitFireGate.nextWarningMarker(stored: nil, day: day, limitMinutes: 30, minutes: 25)
        #expect(m != nil)
        // The burst's lower tiers, and a repeat of the same one, are dropped whatever the order.
        #expect(LimitFireGate.nextWarningMarker(stored: m, day: day, limitMinutes: 30, minutes: 15) == nil)
        #expect(LimitFireGate.nextWarningMarker(stored: m, day: day, limitMinutes: 30, minutes: 25) == nil)
        // A higher tier reached later in the day still fires.
        #expect(LimitFireGate.nextWarningMarker(stored: m, day: day, limitMinutes: 30, minutes: 28) != nil)
    }

    @Test func warningsResetOnANewDayOrLimit() {
        let m = LimitFireGate.nextWarningMarker(stored: nil, day: "2026-09-29", limitMinutes: 30, minutes: 28)
        #expect(LimitFireGate.nextWarningMarker(stored: m, day: day, limitMinutes: 30, minutes: 15) != nil)
        let n = LimitFireGate.nextWarningMarker(stored: nil, day: day, limitMinutes: 30, minutes: 28)
        #expect(LimitFireGate.nextWarningMarker(stored: n, day: day, limitMinutes: 60, minutes: 30) != nil)
    }

    @Test func malformedMarkerIsTreatedAsNothingFired() {
        #expect(LimitFireGate.nextWarningMarker(stored: "garbage", day: day, limitMinutes: 30, minutes: 15) != nil)
    }

    @Test func dayStampIsLocalCalendarDay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let d = cal.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59))!
        #expect(LimitFireGate.dayStamp(d, calendar: cal) == "2026-09-30")
    }

    // MARK: - Re-asserting the shield on a repeat fire

    private var cal: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return c
    }
    private func at(_ hour: Int, day d: Int = 30) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 9, day: d, hour: hour))!
    }

    @Test func hardcoreRepeatFireReraisesALostShield() {
        // Fired at 10:00, nothing released: a relaunch re-fire at 15:00 puts it back.
        #expect(LimitFireGate.shouldReassert(pressure: "Hardcore", released: nil, raised: at(10), now: at(15), calendar: cal))
        #expect(LimitFireGate.shouldReassert(pressure: "Hardcore", released: nil, raised: nil, now: at(15), calendar: cal))
    }

    @Test func standardNeverReraises() {
        #expect(!LimitFireGate.shouldReassert(pressure: "Standard", released: nil, raised: at(10), now: at(15), calendar: cal))
    }

    @Test func releaseAfterTheFireWinsOverARepeatFire() {
        // Raised 10:00, coach Released (or snoozed) 11:00: stays lifted across relaunches.
        #expect(!LimitFireGate.shouldReassert(pressure: "Hardcore", released: at(11), raised: at(10), now: at(15), calendar: cal))
        #expect(!LimitFireGate.shouldReassert(pressure: "Hardcore", released: at(11), raised: nil, now: at(15), calendar: cal))
    }

    @Test func aNewRaiseAfterTheReleaseReenablesReassertion() {
        // Snooze at 11:00, the grace expiry re-locked at 12:00 (a stamped raise).
        #expect(LimitFireGate.shouldReassert(pressure: "Hardcore", released: at(11), raised: at(12), now: at(15), calendar: cal))
    }

    @Test func aReleaseFromAnEarlierDayIsIgnored() {
        #expect(LimitFireGate.shouldReassert(pressure: "Hardcore", released: at(11, day: 29), raised: at(10, day: 29), now: at(15), calendar: cal))
    }

    // MARK: - intervalDidEnd

    @Test func intervalEndClearsOnlyAtTheRealDayBoundary() {
        let late = cal.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 23, minute: 59, second: 59))!
        #expect(DayBoundary.shouldClearShieldOnIntervalEnd(now: late, lastRaisedAt: at(10), calendar: cal))
        // A stop-induced end mid-day keeps the shield.
        #expect(!DayBoundary.shouldClearShieldOnIntervalEnd(now: at(15), lastRaisedAt: at(10), calendar: cal))
        // A delayed boundary callback after midnight, shield raised the day before: clears.
        #expect(DayBoundary.shouldClearShieldOnIntervalEnd(now: at(0, day: 30), lastRaisedAt: at(10, day: 29), calendar: cal))
    }
}

struct ShieldLiftTests {

    @Test func noCoachLockMeansALimitShieldIsLifted() {
        #expect(ShieldLift.decide(coachLockedBy: nil) == .lift)
    }

    @Test func aCoachLockIsKeptAndNamed() {
        #expect(ShieldLift.decide(coachLockedBy: "Alex") == .keepCoachLock(by: "Alex"))
    }

    @Test func anUnnamedCoachLockIsStillKept() {
        #expect(ShieldLift.decide(coachLockedBy: "") == .keepCoachLock(by: nil))
    }
}

struct LaunchGateTests {

    @Test func holdsForMinimumDisplayEvenWhenReady() {
        #expect(!LaunchGate.shouldDismiss(elapsed: 0.1, isReady: true, minDisplay: 0.3, cap: 2.5))
        #expect(LaunchGate.shouldDismiss(elapsed: 0.3, isReady: true, minDisplay: 0.3, cap: 2.5))
    }

    @Test func holdsUntilReadyThenCapOverrides() {
        #expect(!LaunchGate.shouldDismiss(elapsed: 2.0, isReady: false, minDisplay: 0.3, cap: 2.5))
        #expect(LaunchGate.shouldDismiss(elapsed: 2.5, isReady: false, minDisplay: 0.3, cap: 2.5))
    }

    @MainActor @Test func neverReadyStillDismissesAtCap() async {
        let gate = LaunchGate(initiallyVisible: true, minDisplay: 0.05, cap: 0.2)
        await gate.run(isReady: { false })
        #expect(!gate.isVisible)
    }

    @MainActor @Test func notShownWhenNotArmedAndWaitReturnsImmediately() async {
        let gate = LaunchGate(initiallyVisible: false)
        #expect(!gate.isVisible)
        await gate.waitUntilDismissed()
    }

    @MainActor @Test func waitUntilDismissedResumesOnDismiss() async {
        let gate = LaunchGate(initiallyVisible: true, minDisplay: 0, cap: 5)
        async let waiter: Void = gate.waitUntilDismissed()
        await gate.run(isReady: { true })
        await waiter
        #expect(!gate.isVisible)
    }
}
