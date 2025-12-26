//
//  MonitoredAppsDebugView.swift
//  PPTAMinimal
//
//  Created for debugging monitored apps rendering.
//

import SwiftUI
import FamilyControls
import ManagedSettings

/// Simple debug view to verify that the current user's monitored apps
/// (stored as ApplicationToken values in UserSettings.applications)
/// can be rendered via `Label(token)`.
struct MonitoredAppsDebugView: View {
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    
    private var applicationTokens: [ApplicationToken] {
        Array(settingsMgr.userSettings.applications.applicationTokens)
    }
    
    var body: some View {
        List {
            if applicationTokens.isEmpty {
                Text("No monitored apps. Configure them in Settings → App Selection.")
                    .foregroundColor(.secondary)
            } else {
                Section("Monitored Apps (from ApplicationToken)") {
                    ForEach(applicationTokens, id: \.self) { token in
                        // The system will resolve name + icon for this token.
                        Label(token)
                    }
                }
            }
        }
        .navigationTitle("Monitored Apps Debug")
    }
}

#Preview {
    NavigationView {
        MonitoredAppsDebugView()
    }
}


