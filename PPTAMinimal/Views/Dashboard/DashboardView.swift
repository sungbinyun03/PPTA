//
//  DashboardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    
    private var peersYouWatchCount: Int {
        // Prefer uid-based relationships; fall back to legacy phone-based lists during migration.
        if !settingsMgr.userSettings.traineeIds.isEmpty { return settingsMgr.userSettings.traineeIds.count }
        return settingsMgr.userSettings.trainees.count
    }
    
    private var coachesWatchingYouCount: Int {
        if !settingsMgr.userSettings.coachIds.isEmpty { return settingsMgr.userSettings.coachIds.count }
        return settingsMgr.userSettings.coaches.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly stats")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20))
            
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    DashboardCellView(cellTitle: "Daily Time Limit", cellContent: "\(viewModel.limitHours)h \(viewModel.limitMinutes)m")
                    DashboardCellView(cellTitle: "Daily Streak", cellContent: viewModel.streakDays.map {"\($0) Days"} ?? "-")
                }
                HStack(spacing: 14) {
                    DashboardCellView(cellTitle: "Peers you watch", cellContent: "\(peersYouWatchCount)")
                    DashboardCellView(cellTitle: "Coaches watching you", cellContent: "\(coachesWatchingYouCount)")
                }
            }
        }
    }
}

#Preview {
    DashboardView()
}
