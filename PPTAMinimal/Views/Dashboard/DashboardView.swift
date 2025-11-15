//
//  DashboardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    
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
                    DashboardCellView(cellTitle: "Peers you watch", cellContent: "4") // TODO: Fetch values from viewModel
                    DashboardCellView(cellTitle: "Coaches watching you", cellContent: "2") // TODO: Fetch values from viewModel
                }
            }
        }
    }
}

#Preview {
    DashboardView()
}
