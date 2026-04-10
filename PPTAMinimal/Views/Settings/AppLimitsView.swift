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
    @State private var showPressureOffRequiredAlert = false
    @State private var selection = FamilyActivitySelection()
    /// Draft daily limit (saved only when user taps “Save Settings”), like `selection`.
    @State private var draftThresholdHour: Int = 0
    @State private var draftThresholdMinutes: Int = 0
    
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

            // Draft time limit (committed with “Save Settings”), styled like the Daily Limit card
            VStack(spacing: 8) {
                Text("Time limit")
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
                TimeLimitSheetView(draftHours: $draftThresholdHour, draftMinutes: $draftThresholdMinutes)
            }

            // Button to save the selection in Firestore
            Button(action: {
                if saveToFirebase() {
                    showSavedAlert = true
                }
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
        .alert("Turn Pressure to Off first", isPresented: $showPressureOffRequiredAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Turn Pressure level to Off and save first, then you can clear your time limit or remove all apps.")
        }
        .onAppear {
            loadFromUserSettings()
        }
    }
    
    private func loadFromUserSettings() {
        let s = userSettingsManager.userSettings
        self.selection = s.applications
        draftThresholdHour = s.thresholdHour
        draftThresholdMinutes = s.thresholdMinutes
    }
    
    /// - Returns: `true` if settings were saved; `false` if validation blocked the save.
    @discardableResult
    private func saveToFirebase() -> Bool {
        let current = userSettingsManager.userSettings
        let wouldBeViable = UserSettings.appLimitsAreViable(
            thresholdHour: draftThresholdHour,
            thresholdMinutes: draftThresholdMinutes,
            applications: selection
        )
        if !wouldBeViable, current.pressureLevel != "Off" {
            showPressureOffRequiredAlert = true
            return false
        }

        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()

        var settings = userSettingsManager.userSettings

        let oldApps = settings.applications
        let appsChanged =
            oldApps.applicationTokens != selection.applicationTokens ||
            oldApps.categoryTokens != selection.categoryTokens

        let oldTotalSec = settings.thresholdHour * 3600 + settings.thresholdMinutes * 60
        let newTotalSec = draftThresholdHour * 3600 + draftThresholdMinutes * 60
        let limitIncreased = newTotalSec > oldTotalSec

        print("AppLimitsView.saveToFirebase: will persist \(selection.applicationTokens.count) application tokens.")
        for token in selection.applicationTokens {
            print("Selected token:", token)
        }

        if appsChanged || settings.startDailyStreakDate == nil {
            print("Streak start date reset due to app selection change")
            settings.startDailyStreakDate = Date()
        } else if limitIncreased {
            // Previously applied when confirming TimeLimit sheet; now tied to Save Settings.
            settings.startDailyStreakDate = Date()
        }

        settings.applications = selection
        settings.thresholdHour = draftThresholdHour
        settings.thresholdMinutes = draftThresholdMinutes
        userSettingsManager.saveSettings(settings)
        return true
    }

    /// Label for the **draft** daily limit (matches unsaved app selection until Save).
    private var timeLimitDisplayText: String {
        let h = draftThresholdHour
        let m = draftThresholdMinutes
        if h == 0 && m == 0 {
            return "Not set"
        }
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        return parts.joined(separator: " ")
    }
}
