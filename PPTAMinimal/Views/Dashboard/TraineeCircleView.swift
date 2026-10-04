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
    private let snoozeRequestNote: String?

    @State private var showWarningPopover = false
    @State private var showSnoozePopover = false
    @State private var showLockPopover = false

    init(status: TraineeStatus = .allClear, name: String, profilePicUrl: String? = nil, showSetupWarning: Bool = false, showSnoozeRequest: Bool = false,
         lockBadge: CoachActionDisplay.Lock? = nil, lockTooltip: String? = nil, halo: Bool = false, snoozeRequestNote: String? = nil) {
        self.status = status
        self.name = name
        self.profilePicUrl = profilePicUrl
        self.showSetupWarning = showSetupWarning
        self.showSnoozeRequest = showSnoozeRequest
        self.lockBadge = lockBadge
        self.lockTooltip = lockTooltip
        self.halo = halo
        self.snoozeRequestNote = snoozeRequestNote
    }

    private var firstName: String {
        name.split(separator: " ").first.map(String.init) ?? name
    }

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            InitialsProfilePicView(name: name, profilePicUrl: profilePicUrl, size: 75)
                .overlay {
                    Circle()
                        .inset(by: -5)
                        .stroke(status.ringColor ?? .clear, lineWidth: 15)
                    Circle()
                        .stroke((status == .noStatus) ? .clear : Color(.systemBackground), lineWidth: 5)
                }
                // Soft blue ring + glow: this coach snoozed the user's lock. Decorative, not a tap target.
                .overlay {
                    if halo {
                        Circle()
                            .inset(by: -5)
                            .stroke(snoozeBlue.opacity(0.35), lineWidth: 6)
                            .shadow(color: snoozeBlue.opacity(0.6), radius: 8)
                            .allowsHitTesting(false)
                    }
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
                // The coach-lock counterpart of the hand badge: red while this coach's lock is on, grey
                // while it is snoozed. Only ever set for a coach row, so it never overlaps the others.
                .overlay(alignment: .bottom) {
                    if let lockBadge, let lockTooltip {
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
    }

    /// The request note is one the coach RECEIVED, so it is quoted here; the trainee never sees their own.
    private var snoozeRequestText: String {
        let base = "\(firstName) is asking for more time — open their profile to snooze their lock for 10 minutes."
        guard let snoozeRequestNote else { return base }
        return base + "\n\u{201C}\(snoozeRequestNote)\u{201D}"
    }

    private var snoozeBlue: Color { TraineeStatus.snoozedLock.ringColor ?? .blue }
}

#Preview {
    TraineeCircleView(status: TraineeStatus.attentionNeeded, name: "Sungbin")
}

#Preview("Coach locked") {
    TraineeCircleView(status: .noStatus, name: "Alex Kim", lockBadge: .active,
                      lockTooltip: "Alex locked your apps:\n\u{201C}Put it down, exam at 4\u{201D}")
}

#Preview("Coach snoozed") {
    HStack(spacing: 40) {
        TraineeCircleView(status: .noStatus, name: "Alex Kim", lockBadge: .snoozed,
                          lockTooltip: "Alex's note (snoozed by Bea):\n\u{201C}Put it down, exam at 4\u{201D}")
        TraineeCircleView(status: .noStatus, name: "Bea Lee", halo: true)
    }
}
