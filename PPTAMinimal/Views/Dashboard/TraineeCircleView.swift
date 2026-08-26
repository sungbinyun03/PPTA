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

    @State private var showWarningPopover = false
    @State private var showSnoozePopover = false

    init(status: TraineeStatus = .allClear, name: String, profilePicUrl: String? = nil, showSetupWarning: Bool = false, showSnoozeRequest: Bool = false) {
        self.status = status
        self.name = name
        self.profilePicUrl = profilePicUrl
        self.showSetupWarning = showSetupWarning
        self.showSnoozeRequest = showSnoozeRequest
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
                            Text("Your trainee hasn't set their App Limits or Pressure Level yet — remind them to get set up so they can start locking in!")
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
                            Text("\(firstName) is asking for more time — open their profile to snooze their lock for 10 minutes.")
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
}

#Preview {
    TraineeCircleView(status: TraineeStatus.attentionNeeded, name: "Sungbin")
}
