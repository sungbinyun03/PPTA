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
                    ForEach(Array(selection.applicationTokens.enumerated()), id: \.element) { index, token in
                        HStack {
                            Label(token) // The token's description (or "label") for now
                            Spacer()
                        }
                        if index < selection.applicationTokens.count - 1 {
                            Divider()
                        }
                    }
                    
                    ForEach(Array(selection.categoryTokens.enumerated()), id: \.element) { index, token in
                        HStack {
                            Label(token)
                            Spacer()
                        }
                        if index < selection.categoryTokens.count - 1 {
                            Divider()
                        }
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
        userSettingsManager.userSettings.applications = selection
        
        // Save to Firestore
        userSettingsManager.saveSettings(userSettingsManager.userSettings)
    }
}



