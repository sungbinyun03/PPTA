import SwiftUI

struct PressureLevelView: View {
    @ObservedObject var userSettingsManager = UserSettingsManager.shared

    /// Mirrors `UserSettings.pressureLevel`: Off, Standard, or Hardcore.
    @State private var draftPressureLevel: PressureLevel = PressureLevel.off
    @State private var showConfirmedAlert = false
    @State private var showViableLimitsRequiredAlert = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Pressure Level")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Choose how strongly your friends can hold you accountable.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            VStack(spacing: 12) {
                PressureLevelCard(
                    level: PressureLevel.off,
                    title: "Off",
                    description: "No monitoring or pressure.\nTake a break :)",
                    backgroundColor: Color("primaryColor").opacity(0.08),
                    textColor: Color("primaryColor"),
                    showStar: false,
                    selection: $draftPressureLevel
                )
                PressureLevelCard(
                    level: PressureLevel.standard,
                    title: "Standard",
                    description: "Coaches can lock out\nTrainees when they exceed.",
                    backgroundColor: Color("primaryButtonColor"),
                    textColor: .white,
                    showStar: true,
                    selection: $draftPressureLevel
                )
                PressureLevelCard(
                    level: PressureLevel.hardcore,
                    title: "Hardcore",
                    description: "Trainees get locked\ninstantly when they exceed.",
                    backgroundColor: Color("primaryColor"),
                    textColor: .white,
                    showStar: false,
                    selection: $draftPressureLevel
                )
            }
            .padding(.horizontal)

            PrimaryButton(title: "Save Settings", action: saveToFirebase)
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer(minLength: 20)
        }
        .padding(.vertical, 20)
        .appAlert(
            isPresented: $showConfirmedAlert,
            title: "Saved",
            message: "Your coaches have been informed of your new pressure level!"
        )
        .appAlert(
            isPresented: $showViableLimitsRequiredAlert,
            title: "Set up App Limits first",
            message: "Set a daily time limit and at least one app or category in App Limits, tap Save Settings, then try again."
        )
        .onAppear {
            loadFromUserSettings()
        }
    }

    private func loadFromUserSettings() {
        draftPressureLevel = userSettingsManager.userSettings.pressureLevel
    }

    private func saveToFirebase() {
        if draftPressureLevel != PressureLevel.off, !userSettingsManager.userSettings.hasViableAppLimits {
            showViableLimitsRequiredAlert = true
            return
        }

        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()

        userSettingsManager.userSettings.pressureLevel = draftPressureLevel
        userSettingsManager.saveSettings(userSettingsManager.userSettings)
        showConfirmedAlert = true
    }
}
