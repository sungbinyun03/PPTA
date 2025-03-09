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
    let isMonitoring: Bool

    private func requestScreenTimePermission() {
        let center = AuthorizationCenter.shared
        if center.authorizationStatus != .approved {
            Task {
                do {
                    try await center.requestAuthorization(for: .individual)
                    print("Requested FamilyControls/ScreenTime permission.")
                } catch {
                    print("Failed to request screen time auth: \(error)")
                }
            }
        } else {
            print("Already approved for Screen Time.")
        }
    }
    
    @State var context: DeviceActivityReport.Context = .init(rawValue: "Total Activity")
    @State private var selection = FamilyActivitySelection()
    @State var filter = DeviceActivityFilter(
        segment: .daily(
            during: Calendar.current.dateInterval(of: .day, for: .now)!
        ),
        users: .all,
        devices: .init([.iPhone, .iPad])
    )
    
    var body: some View {
        
        VStack {
            if AuthorizationCenter.shared.authorizationStatus == .approved {
                DeviceActivityReport(context, filter: filter)
                    .frame(minHeight: 395)
            } else {
                Text("Unable to load activity report. Please ensure permissions are granted.")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .onAppear {
            requestScreenTimePermission()
            
            if isMonitoring {
                Task {
                    UserSettingsManager.shared.loadSettings { settings in
                        selection = settings.applications
                        filter = DeviceActivityFilter(
                            segment: .daily(
                                during: Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
                            ),
                            users: .all,
                            devices: .init([.iPhone]),
                            applications: selection.applicationTokens,
                            categories: selection.categoryTokens
                        )
                    }
                }
            }
        }
    }
}
