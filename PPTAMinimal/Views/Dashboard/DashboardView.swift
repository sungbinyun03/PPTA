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
    @State private var showSettingsWarning = false

    private var peersYouWatchCount: Int {
        if !settingsMgr.userSettings.traineeIds.isEmpty { return settingsMgr.userSettings.traineeIds.count }
        return settingsMgr.userSettings.trainees.count
    }

    private var coachesWatchingYouCount: Int {
        if !settingsMgr.userSettings.coachIds.isEmpty { return settingsMgr.userSettings.coachIds.count }
        return settingsMgr.userSettings.coaches.count
    }

    private var settingsWarnings: [String] {
        var msgs: [String] = []
        if !settingsMgr.userSettings.hasViableAppLimits {
            msgs.append("No app limits set — go to Settings → App Limits to choose apps and set your daily limit.")
        }
        if settingsMgr.userSettings.pressureLevel == .off {
            msgs.append("Pressure level is Off — go to Settings → Pressure Level to enable accountability.")
        }
        return msgs
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Stats")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                if !settingsWarnings.isEmpty {
                    Button { showSettingsWarning = true } label: {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettingsWarning) {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(settingsWarnings, id: \.self) { msg in
                                Text(msg).font(.subheadline)
                            }
                        }
                        .padding(16)
                        .frame(maxWidth: 280)
                        .presentationCompactAdaptation(.popover)
                    }
                }
            }

            MarqueeStatsView(items: [
                ("DAILY LIMIT", "\(viewModel.limitHours)h \(viewModel.limitMinutes)m"),
                ("STREAK", viewModel.streakDays.map { "\($0) \($0 == 1 ? "day" : "days")" } ?? "—"),
                ("WATCHING", "\(peersYouWatchCount)"),
                ("COACHES", "\(coachesWatchingYouCount)"),
            ])
        }
        .padding(.horizontal, 24)
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
