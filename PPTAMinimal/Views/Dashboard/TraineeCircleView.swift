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

    @State private var showWarningPopover = false

    init(status: TraineeStatus = .allClear, name: String, profilePicUrl: String? = nil, showSetupWarning: Bool = false) {
        self.status = status
        self.name = name
        self.profilePicUrl = profilePicUrl
        self.showSetupWarning = showSetupWarning
    }

    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            InitialsProfilePicView(name: name, profilePicUrl: profilePicUrl, size: 75)
                .overlay {
                    Circle()
                        .inset(by: -5)
                        .stroke(status.ringColor ?? .clear, lineWidth: 15)
                    Circle()
                        .stroke((status == .noStatus) ? .clear : .white, lineWidth: 5)
                }
                .overlay(alignment: .bottom) {
                    if showSetupWarning {
                        Button { showWarningPopover = true } label: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.orange)
                                .background(Circle().fill(Color.white).padding(-2))
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
            Text(name)
                .font(.custom("SatoshiVariable-Bold_Light", size: 15))
        }
    }
}

#Preview {
    TraineeCircleView(status: TraineeStatus.attentionNeeded, name: "Sungbin")
}
