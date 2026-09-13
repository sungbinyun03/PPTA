//
//  SetupCardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

/// A single "Setup incomplete" checklist shown on Home while anything is still missing: App Limits,
/// Friends, Trainees, or Coaches. Coaches/Trainees are flagged whenever there's none — pending
/// (unaccepted) requests don't suppress it, keeping the logic simple and predictable.
struct SetupCardView: View {
    @StateObject private var friendsVm = FriendsViewModel()
    @ObservedObject private var settingsMgr = UserSettingsManager.shared

    private var hasCoach: Bool {
        !settingsMgr.userSettings.coachIds.isEmpty || !settingsMgr.userSettings.coaches.isEmpty
    }

    private var missingItems: [String] {
        var items: [String] = []
        // Pressure Level now lives inside App Limits, so a single "App Limits" item covers a missing
        // time limit, no apps, or pressure still Off.
        if !settingsMgr.userSettings.hasViableAppLimits || settingsMgr.userSettings.pressureLevel == .off {
            items.append("App Limits")
        }
        if friendsVm.friends.isEmpty { items.append("Friends") }
        if settingsMgr.userSettings.traineeIds.isEmpty && settingsMgr.userSettings.trainees.isEmpty {
            items.append("Trainees")
        }
        if !hasCoach { items.append("Coaches") }
        return items
    }

    var body: some View {
        Group {
            if !missingItems.isEmpty {
                setupCard
            }
        }
        .padding(.horizontal, 24)
        .task {
            await friendsVm.refresh()
        }
    }

    // MARK: - Checklist

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.orange)
                Text("Setup incomplete")
                    .font(.custom("BambiBold", size: 15))
                    .foregroundColor(.orange)
            }

            Text("Follow the warning icons to set up the following:")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(missingItems, id: \.self) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text(item)
                            .font(.custom("Satoshi-Variable", size: 13))
                            .foregroundColor(.primary)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    SetupCardView()
}
