//
//  AppSelectView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 4/5/25.
//

import SwiftUI
import FamilyControls

struct AppSelectView: View {
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    
    @State private var isPickerPresented = false
    @State private var selection = FamilyActivitySelection()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("App Selection")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose which apps (or categories) you want to monitor.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 12) {
                if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                    Text("No apps selected yet.")
                        .foregroundColor(.secondary)
                } else {
                    // Show each selected application token
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        HStack {
                            Label(token)
                            Spacer()
                        }
                        Divider()
                    }
                    
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        HStack {
                            Label(token)
                            Spacer()
                        }
                        Divider()
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: { isPickerPresented = true }) {
                Label("Add Apps", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            // This modifier brings up the FamilyActivityPicker
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            
            // Button to save the selection in Firestore
            Button(action: saveToFirebase) {
                Text("Save Selection")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            loadFromUserSettings()
        }
    }
    
    private func loadFromUserSettings() {
        self.selection = userSettingsManager.userSettings.applications
    }
    
    private func saveToFirebase() {
        // Update local userSettings
        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()
        
        var settings = userSettingsManager.userSettings
        
        // Capture whether selection changed (simple proxy comparing tokens)
        let old = settings.applications
        let appsChanged =
            old.applicationTokens != selection.applicationTokens ||
            old.categoryTokens != selection.categoryTokens
        
        print("AppSelectView.saveToFirebase: will persist \(selection.applicationTokens.count) application tokens.")
        for token in selection.applicationTokens {
            print("Selected token:", token)
        }
        
        // Reset streak if app selection changed or streak was never started.
        if appsChanged || settings.startDailyStreakDate == nil {
            print("Streak start date reset due to app selection change")
            settings.startDailyStreakDate = Date()
        }

        // Save updated selection & stats to Firestore.
        settings.applications = selection
        userSettingsManager.saveSettings(settings)
    }
}



