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
            print("Already approved for Screen Time.")
            return
        }

        isRequestingPermission = true
        defer { isRequestingPermission = false }

        do {
            try await center.requestAuthorization(for: .individual)
            print("Requested FamilyControls/ScreenTime permission.")
        } catch {
            print("Failed to request screen time auth: \(error)")
        }

        authorizationStatus = center.authorizationStatus
    }

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

    @State var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")

    var body: some View {
        VStack {
            if authorizationStatus == .approved {
                DeviceActivityReport(context, filter: currentFilter)
                    .frame(minHeight: 395)
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
