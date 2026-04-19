//
//  ReportView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/27/25.
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct ReportView: View {
    @ObservedObject private var userSettingsManager = UserSettingsManager.shared
    @State private var authorizationStatus = AuthorizationCenter.shared.authorizationStatus
    @State private var isRequestingPermission = false

    private func requestScreenTimePermission() async {
        let center = AuthorizationCenter.shared
        guard center.authorizationStatus != .approved else {
            authorizationStatus = .approved
            return
        }
        isRequestingPermission = true
        defer { isRequestingPermission = false }
        do {
            try await center.requestAuthorization(for: .individual)
        } catch {
            print("Failed to request screen time auth: \(error)")
        }
        authorizationStatus = center.authorizationStatus
    }

    // Today with hourly segmentation — feeds the progress ring, per-app list, and hourly chart
    private var currentFilter: DeviceActivityFilter {
        let selection = userSettingsManager.userSettings.applications
        let todayInterval = Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            return DeviceActivityFilter(
                segment: .hourly(during: todayInterval),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: .hourly(during: todayInterval),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )
    }

    // Last 7 days with daily segmentation — feeds the weekly bar chart
    private var weeklyFilter: DeviceActivityFilter {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: .now)
        let weekStart = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
        let last7Days = DateInterval(start: weekStart, end: .now)
        let selection = userSettingsManager.userSettings.applications
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            return DeviceActivityFilter(
                segment: .daily(during: last7Days),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: .daily(during: last7Days),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )
    }

    var body: some View {
        Group {
            if authorizationStatus == .approved {
                VStack(spacing: 0) {
                    DeviceActivityReport(.init("Weekly Trend"), filter: weeklyFilter)
                        .frame(height: 140)
                    DeviceActivityReport(.init("Total Activity"), filter: currentFilter)
                        .frame(minHeight: 500)
                }
            } else if isRequestingPermission {
                ProgressView("Requesting Screen Time access...")
                    .padding()
            } else {
                Text("Unable to load activity report. Please ensure permissions are granted.")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .task {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            await requestScreenTimePermission()
        }
    }
}
