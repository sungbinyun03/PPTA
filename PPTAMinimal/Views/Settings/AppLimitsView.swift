//
//  AppLimitsView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 4/5/25.
//

import SwiftUI
import FamilyControls

struct AppLimitsView: View {
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    
    @State private var isPickerPresented = false
    @State private var showTimeLimitSheet = false
    @State private var showSavedAlert = false
    @State private var selection = FamilyActivitySelection()
    
    var body: some View {
        VStack(spacing: 20) {
            Text("App Limits")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()
            
            (Text("Note: ").fontWeight(.bold) + Text("Your streak resets when (TODO) blah blah blah"))
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            // Current saved time limit (read-only), styled like PressureLevelView’s Daily Limit card
            VStack(spacing: 8) {
                Text("Current time limit")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                Text(timeLimitDisplayText)
                    .font(.title2)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.gray.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 15))
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 2)
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
                        Text("No apps selected yet.")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .frame(height: 44)
                            .padding(.horizontal, 4)
                    } else {
                        // App tokens: fixed-height rows
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            HStack {
                                Label(token)
                                Spacer()
                            }
                            .frame(height: 44)
                            .padding(.horizontal, 4)
                            Divider()
                        }
                        // Category tokens: fixed-height rows
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            HStack {
                                Label(token)
                                Spacer()
                            }
                            .frame(height: 44)
                            .padding(.horizontal, 4)
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 180)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            
            Button(action: { isPickerPresented = true }) {
                Label("Select Apps", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            // This modifier brings up the FamilyActivityPicker
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            
            Button(action: { showTimeLimitSheet = true }) {
                Label("Select Time Limit", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(10)
            }
            .sheet(isPresented: $showTimeLimitSheet) {
                TimeLimitSheetView()
            }

            // Button to save the selection in Firestore
            Button(action: {
                saveToFirebase()
                showSavedAlert = true
            }) {
                Text("Save Settings")
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
        .alert("Settings Saved!", isPresented: $showSavedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Make sure to screenshot and share them with your coaches so they know what your goals are!")
        }
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
        
        print("AppLimitsView.saveToFirebase: will persist \(selection.applicationTokens.count) application tokens.")
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

    /// Read-only label for the current saved daily limit (e.g. "2h 30m").
    private var timeLimitDisplayText: String {
        let h = userSettingsManager.userSettings.thresholdHour
        let m = userSettingsManager.userSettings.thresholdMinutes
        if h == 0 && m == 0 {
            return "Not set"
        }
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        return parts.joined(separator: " ")
    }
}
