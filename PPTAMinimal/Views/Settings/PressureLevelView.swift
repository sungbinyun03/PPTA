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
                pressureCard(
                    level: PressureLevel.off,
                    title: "Off",
                    description: "No monitoring or pressure.\nTake a break :)",
                    backgroundColor: Color("primaryColor").opacity(0.08),
                    textColor: Color("primaryColor"),
                    showStar: false
                )
                pressureCard(
                    level: PressureLevel.standard,
                    title: "Standard",
                    description: "Coaches can lock out\nTrainees when they exceed.",
                    backgroundColor: Color("primaryButtonColor"),
                    textColor: .white,
                    showStar: true
                )
                pressureCard(
                    level: PressureLevel.hardcore,
                    title: "Hardcore",
                    description: "Trainees get locked\ninstantly when they exceed.",
                    backgroundColor: Color("primaryColor"),
                    textColor: .white,
                    showStar: false
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

    @ViewBuilder
    private func pressureCard(
        level: PressureLevel,
        title: String,
        description: String,
        backgroundColor: Color,
        textColor: Color,
        showStar: Bool
    ) -> some View {
        Button {
            draftPressureLevel = level
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .stroke(Color.primary.opacity(textColor == .white ? 0.5 : 0.3), lineWidth: 2)
                    .background(
                        Circle()
                            .fill(draftPressureLevel == level ? (textColor == .white ? Color.white : Color.primary) : Color.clear)
                            .scaleEffect(draftPressureLevel == level ? 0.5 : 0)
                    )
                    .frame(width: 24, height: 24)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(textColor)
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(textColor.opacity(0.9))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if showStar {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.title3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
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
