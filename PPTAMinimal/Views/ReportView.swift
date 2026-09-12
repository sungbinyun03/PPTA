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
    @State private var showPressureLevelInfo = false
    /// Same key HomeView reads, so the expanded ring rebases in lockstep with the summary ring on a
    /// settings change. Matches `DeviceActivityManager.ringResetKey`.
    @AppStorage("ringResetAt") private var ringResetAt: Double = 0

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

    // Today, full-day — feeds the progress ring and per-app list. The report extension scopes these
    // figures to the current monitoring session via `RingSession` (baseline subtraction); a filter
    // can't window sub-hour. **Must stay identical to `HomeView.summaryFilter`** so the two rings
    // agree. `.daily` (one exact day bucket) rather than `.hourly`; if the hourly bar chart in
    // `TotalActivityView` is ever re-enabled, switch both filters back to `.hourly` together.
    // `.id(ringResetAt)` below forces a fresh rebasing render when the user saves a settings change.
    private var currentFilter: DeviceActivityFilter {
        let selection = userSettingsManager.userSettings.applications
        let todayInterval = Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            return DeviceActivityFilter(
                segment: .daily(during: todayInterval),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: .daily(during: todayInterval),
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

    private var streakDays: Int {
        StreakCalculator.daysSince(
            start: userSettingsManager.userSettings.startDailyStreakDate,
            calendar: .current
        )
    }

    private var streakHeader: some View {
        let isTracking = userSettingsManager.userSettings.isTracking
        let label = isTracking
            ? "DAILY STREAK: \(streakDays) DAY\(streakDays == 1 ? "" : "S")"
            : "DAILY STREAK: PAUSED"
        return HStack(spacing: 6) {
            Text(label)
                .font(.custom("Satoshi-Variable", size: 13))
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundColor(Color("primaryColor").opacity(0.6))
            if !isTracking {
                Button { showPressureLevelInfo = true } label: {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPressureLevelInfo) {
                    Text("Go to Settings → App Limits to activate tracking. Without it, your status and streak won't update.")
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(16)
                        .frame(width: 260)
                        .presentationCompactAdaptation(.popover)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    var body: some View {
        Group {
            if authorizationStatus == .approved {
                VStack(spacing: 0) {
                    streakHeader
                    // Last 7 days chart — not needed right now but may be useful in the future
                    // DeviceActivityReport(.init("Weekly Trend"), filter: weeklyFilter)
                    //     .frame(height: 140)
                    // `.id(ringResetAt)` forces a fresh query when the user saves a settings change,
                    // so this expanded ring/list rebases in lockstep with the Home summary ring.
                    DeviceActivityReport(.init("Total Activity"), filter: currentFilter)
                        .id(ringResetAt)
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
