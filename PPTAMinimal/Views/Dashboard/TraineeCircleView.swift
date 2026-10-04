//
//  TraineeCoachCircleView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCircleView: View {
    private let status: TraineeStatus
    private let name: String
    private let profilePicUrl: String?
    private let showSetupWarning: Bool
    private let showSnoozeRequest: Bool
    private let lockBadge: CoachActionDisplay.Lock?
    private let lockTooltip: String?
    private let halo: Bool
    private let haloTooltip: String?
    private let snoozeRequestNote: String?
    private let autoOpenKey: String?
    private let onAutoOpenDismiss: (String) -> Void

    @State private var showWarningPopover = false
    @State private var showSnoozePopover = false
    @State private var showLockPopover = false
    @State private var showHaloPopover = false
    /// True while the open popover was opened by `autoOpenKey` rather than a tap.
    @State private var autoOpened = false
    /// Set while re-presenting on foreground, so closing the stale popover isn't reported as a dismissal.
    @State private var suppressDismissReport = false
    @Environment(\.scenePhase) private var scenePhase

    init(status: TraineeStatus = .allClear, name: String, profilePicUrl: String? = nil, showSetupWarning: Bool = false, showSnoozeRequest: Bool = false,
         lockBadge: CoachActionDisplay.Lock? = nil, lockTooltip: String? = nil, halo: Bool = false, haloTooltip: String? = nil, snoozeRequestNote: String? = nil,
         autoOpenKey: String? = nil, onAutoOpenDismiss: @escaping (String) -> Void = { _ in }) {
        self.status = status
        self.name = name
        self.profilePicUrl = profilePicUrl
        self.showSetupWarning = showSetupWarning
        self.showSnoozeRequest = showSnoozeRequest
        self.lockBadge = lockBadge
        self.lockTooltip = lockTooltip
        self.halo = halo
        self.haloTooltip = haloTooltip
        self.snoozeRequestNote = snoozeRequestNote
        self.autoOpenKey = autoOpenKey
        self.onAutoOpenDismiss = onAutoOpenDismiss
    }

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        VStack(alignment: .center, spacing: 14) {
            InitialsProfilePicView(name: name, profilePicUrl: profilePicUrl, size: 64)
                .overlay {
                    Circle()
                        .inset(by: -5)
                        .stroke(status.ringColor ?? .clear, lineWidth: 15)
                    Circle()
                        .stroke((status == .noStatus) ? .clear : Color(.systemBackground), lineWidth: 5)
                }
                .overlay(alignment: .bottom) {
                    if showSetupWarning {
                        Button { showWarningPopover = true } label: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                                .background(Circle().fill(Color(.systemBackground)).padding(-2))
                        }
                        .buttonStyle(.plain)
                        .offset(y: 10)
                        .popover(isPresented: $showWarningPopover) {
                            Text("Your trainee hasn't fully set their App Limits yet — remind them to get set up so they can start locking in!")
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .frame(width: 260)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                // Mutually exclusive with the setup warning (that shows only when unset; this only
                // while cut off), so they never overlap despite sharing the bottom slot.
                .overlay(alignment: .bottom) {
                    if showSnoozeRequest {
                        Button { showSnoozePopover = true } label: {
                            // `hand.raised.fill` isn't a circle glyph like `exclamationmark.circle.fill`,
                            // so we build the round badge ourselves: white hand inside a blue circle
                            // (the snooze-lock status colour), sized to match the warning badge.
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 21, height: 21)
                                .background(Circle().fill(TraineeStatus.snoozedLock.ringColor ?? .blue))
                                .background(Circle().fill(Color(.systemBackground)).padding(-2))
                        }
                        .buttonStyle(.plain)
                        .offset(y: 10)
                        .popover(isPresented: $showSnoozePopover) {
                            Text(snoozeRequestText)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .frame(width: 260)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
                // The snooze counterpart of the lock badge, in the same slot: this coach snoozed the user's
                // lock. It replaces that coach's lock badge, so the two never overlap. A tap target only when
                // there is a note for the tooltip; the avatar itself still opens the profile.
                .overlay(alignment: .bottom) {
                    if halo {
                        if let haloTooltip {
                            Button { showHaloPopover = true } label: { haloBadge }
                                .buttonStyle(.plain)
                                .offset(y: 10)
                                .popover(isPresented: $showHaloPopover, arrowEdge: .bottom) {
                                    Text(haloTooltip)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(16)
                                        .frame(width: 260)
                                        .presentationCompactAdaptation(.popover)
                                }
                        } else {
                            haloBadge.offset(y: 10)
                        }
                    }
                }
                // The coach-lock counterpart of the hand badge: red while this coach's lock is on, grey
                // while it is snoozed. Only ever set for a coach row, so it never overlaps the others.
                .overlay(alignment: .bottom) {
                    if !halo, let lockBadge, let lockTooltip {
                        Button { showLockPopover = true } label: {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 21, height: 21)
                                .background(Circle().fill(lockBadge == .active ? Color.red : Color(.systemGray)))
                                .background(Circle().fill(Color(.systemBackground)).padding(-2))
                        }
                        .buttonStyle(.plain)
                        .offset(y: 10)
                        .popover(isPresented: $showLockPopover, arrowEdge: .bottom) {
                            Text(lockTooltip)
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .frame(width: 260)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
            Text(name)
                .font(.custom("SatoshiVariable-Bold_Light", size: 15))
        }
        // Default-open: the parent names the one tooltip that should be open (a coach's lock note, or
        // the snoozing coach's note, or the latest snooze request) and withdraws the key to close it.
        // The key's prefix says which popover it is.
        .onChange(of: autoOpenKey, initial: true) { _, key in
            if key != nil { presentAutoOpen(key) } else if autoOpened { closeAutoOpen() }
        }
        .onChange(of: showLockPopover) { _, open in autoOpenClosed(open) }
        .onChange(of: showSnoozePopover) { _, open in autoOpenClosed(open) }
        .onChange(of: showHaloPopover) { _, open in autoOpenClosed(open) }
        // A lock that lands while the app is backgrounded (silent push) sets the key off-screen, where a
        // popover can't present; open it when the app comes back.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, let key = autoOpenKey else { return }
            if autoOpened {
                suppressDismissReport = true
                closeAutoOpen()
            }
            presentAutoOpen(key)
        }
    }

    private func presentAutoOpen(_ key: String?) {
        guard let key else { return }
        // Same wait as the shield handoff popover: one presented under the launch facade or mid
        // tab transition is dropped. Re-checks the key after the wait; the parent may have withdrawn it.
        Task { @MainActor in
            await LaunchGate.shared.waitUntilDismissed()
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard autoOpenKey == key, !showLockPopover, !showSnoozePopover, !showHaloPopover else { return }
            // Not on screen yet: the scenePhase handler retries when the app becomes active.
            guard UIApplication.shared.applicationState == .active else { return }
            autoOpened = true
            if key.hasPrefix("lock|") { showLockPopover = true }
            else if key.hasPrefix("snooze|") { showHaloPopover = true }
            else { showSnoozePopover = true }
        }
    }

    private func closeAutoOpen() {
        autoOpened = false
        showLockPopover = false
        showSnoozePopover = false
        showHaloPopover = false
    }

    /// The user closed the popover: report the key so it stays closed for this lock or request.
    private func autoOpenClosed(_ open: Bool) {
        guard !open else { return }
        if suppressDismissReport { suppressDismissReport = false; return }
        guard let key = autoOpenKey else { return }
        autoOpened = false
        onAutoOpenDismiss(key)
    }

    private var snoozeRequestText: String {
        ActionMessage.snoozeRequestTooltip(firstName: firstName, note: snoozeRequestNote)
    }

    /// Snooze-blue circle with a white heart.badge.bolt, sized and ringed like the lock badge.
    private var haloBadge: some View {
        Image(systemName: Self.haloSymbol)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 21, height: 21)
            .background(Circle().fill(snoozeBlue))
            .background(Circle().fill(Color(.systemBackground)).padding(-2))
    }

    /// heart.badge.bolt may be missing on older iOS 17 symbol sets; fall back to a plain heart.
    private static let haloSymbol = UIImage(systemName: "heart.badge.bolt") != nil ? "heart.badge.bolt" : "heart.fill"

    private var snoozeBlue: Color { TraineeStatus.snoozedLock.ringColor ?? .blue }
}

#Preview {
    TraineeCircleView(status: TraineeStatus.attentionNeeded, name: "Sungbin")
}

#Preview("Coach locked") {
    TraineeCircleView(status: .noStatus, name: "Alex Kim", lockBadge: .active,
                      lockTooltip: "Put it down, exam at 4")
}

#Preview("Coach snoozed") {
    HStack(spacing: 40) {
        TraineeCircleView(status: .noStatus, name: "Alex Kim", lockBadge: .snoozed,
                          lockTooltip: "Put it down, exam at 4")
        TraineeCircleView(status: .noStatus, name: "Bea Lee", halo: true, haloTooltip: "10 min, go")
    }
}
