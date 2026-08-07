//
//  DashboardView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @StateObject private var friendsVm = FriendsViewModel()
    @ObservedObject private var settingsMgr = UserSettingsManager.shared

    private var peersYouWatchCount: Int {
        if !settingsMgr.userSettings.traineeIds.isEmpty { return settingsMgr.userSettings.traineeIds.count }
        return settingsMgr.userSettings.trainees.count
    }

    private var coachesWatchingYouCount: Int {
        if !settingsMgr.userSettings.coachIds.isEmpty { return settingsMgr.userSettings.coachIds.count }
        return settingsMgr.userSettings.coaches.count
    }

    private var missingItems: [String] {
        var items: [String] = []
        if !settingsMgr.userSettings.hasViableAppLimits { items.append("App Limits") }
        if settingsMgr.userSettings.pressureLevel == .off { items.append("Pressure Level") }
        if friendsVm.friends.isEmpty { items.append("Friends") }
        if settingsMgr.userSettings.traineeIds.isEmpty && settingsMgr.userSettings.trainees.isEmpty {
            items.append("Trainees")
        }
        if settingsMgr.userSettings.coachIds.isEmpty && settingsMgr.userSettings.coaches.isEmpty {
            items.append("Coaches")
        }
        return items
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !missingItems.isEmpty {
                setupCard
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Stats")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))

                MarqueeStatsView(items: [
                    ("DAILY LIMIT", "\(viewModel.limitHours)h \(viewModel.limitMinutes)m"),
                    ("STREAK", viewModel.streakDays.map { "\($0) \($0 == 1 ? "day" : "days")" } ?? "—"),
                    ("WATCHING", "\(peersYouWatchCount)"),
                    ("COACHES", "\(coachesWatchingYouCount)"),
                ])
            }
        }
        .padding(.horizontal, 24)
        .task { await friendsVm.refresh() }
    }

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

// MARK: - Marquee

private struct MarqueeStatsView: View {
    let items: [(label: String, value: String)]
    @State private var contentWidth: CGFloat = 0
    @State private var animating = false

    var body: some View {
        Color.clear
            .frame(height: 30)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .leading) {
                HStack(spacing: 0) {
                    rowContent
                    rowContent
                }
                .fixedSize(horizontal: true, vertical: false)
                .offset(x: animating ? -contentWidth : 0)
            }
            .clipped()
            .background(
                rowContent
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                guard contentWidth == 0, geo.size.width > 0 else { return }
                                contentWidth = geo.size.width
                                withAnimation(
                                    .linear(duration: Double(geo.size.width) / 55)
                                    .repeatForever(autoreverses: false)
                                ) {
                                    animating = true
                                }
                            }
                        }
                    )
            )
    }

    private var rowContent: some View {
        HStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                HStack(spacing: 6) {
                    Text(items[i].label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color("primaryColor").opacity(0.5))
                        .kerning(0.5)
                    Text(items[i].value)
                        .font(.custom("BambiBold", size: 14))
                        .foregroundColor(Color("primaryColor"))
                }
                Text("   ·   ")
                    .font(.system(size: 11))
                    .foregroundColor(Color("primaryColor").opacity(0.3))
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    DashboardView()
}
