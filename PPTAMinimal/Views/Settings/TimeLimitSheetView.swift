//
//  TimeLimitSheetView.swift
//  PPTAMinimal
//
//  Sheet containing the daily time limit picker (hours/minutes dial).
//

import SwiftUI

struct TimeLimitSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var userSettingsManager = UserSettingsManager.shared

    @State private var hours: Int = 0
    @State private var minutes: Int = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Set your daily screen time limit.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                // Same dial as PressureLevelView: Hours + Minutes wheel pickers
                VStack(spacing: 16) {
                    Text("Daily Limit")
                        .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                        .padding(.top, 10)

                    HStack(spacing: 12) {
                        VStack {
                            Picker("Hours", selection: $hours) {
                                ForEach(0...23, id: \.self) { hour in
                                    Text(String(format: "%02d", hour))
                                        .tag(hour)
                                }
                            }
                            .frame(width: 60, height: 120)
                            .clipped()
                            .pickerStyle(.wheel)
                            Text("Hours")
                                .font(.footnote)
                        }

                        VStack {
                            Picker("Minutes", selection: $minutes) {
                                ForEach(0...59, id: \.self) { min in
                                    Text(String(format: "%02d", min))
                                        .tag(min)
                                }
                            }
                            .frame(width: 60, height: 120)
                            .clipped()
                            .pickerStyle(.wheel)
                            Text("Minutes")
                                .font(.footnote)
                        }
                    }
                }
                .frame(maxWidth: 340)
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 4)
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Time Limit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.primary)
                            .frame(width: 39, height: 39)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Cancel")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveAndDismiss()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .frame(width: 45, height: 45)
                            .background(Color.blue)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Confirm selection")
                }
            }
            .onAppear {
                loadFromUserSettings()
            }
        }
    }

    /// Reads duration from the in-memory cache only (no Firebase fetch here).
    /// The cache is filled when HomeView loads (Firebase) or after a previous save.
    private func loadFromUserSettings() {
        let settings = userSettingsManager.userSettings
        hours = settings.thresholdHour
        minutes = settings.thresholdMinutes
    }

    private func saveAndDismiss() {
        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()

        let old = userSettingsManager.userSettings
        let oldTotal = old.thresholdHour * 3600 + old.thresholdMinutes * 60
        let newTotal = hours * 3600 + minutes * 60

        if newTotal > oldTotal || userSettingsManager.userSettings.startDailyStreakDate == nil {
            userSettingsManager.userSettings.startDailyStreakDate = Date()
        }

        userSettingsManager.userSettings.thresholdHour = hours
        userSettingsManager.userSettings.thresholdMinutes = minutes
        userSettingsManager.saveSettings(userSettingsManager.userSettings)
        dismiss()
    }
}
