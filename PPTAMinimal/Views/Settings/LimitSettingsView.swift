import SwiftUI

struct LimitSettingsView: View {
    @ObservedObject var userSettingsManager = UserSettingsManager.shared

    // Local states mirroring userSettings
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0

    // Single string to store the selected mode
    @State private var selectedMode: String = "Chill" // Default

    var body: some View {
            VStack(spacing: 20) {
                
                // Main Title
                Text("Limit Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Horizontal divider under the title
                Divider()
                
                // Explanatory text
                Text("Set Your Screen Time Limit: Choose how much time you'd like to spend online, and choose your limit preferences!")
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.secondary)
                
                // Rounded rectangle container for daily limit & pickers
                VStack(spacing: 16) {
                    Text("Daily Limit")
                        .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                        .padding(.top, 10)
                    
                    // HStack with Hours, Minutes, Seconds pickers
                    HStack(spacing: 12) {
                        // Hours
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
                        
                        // Minutes
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

                        // Seconds
                        VStack {
                            Picker("Seconds", selection: $seconds) {
                                ForEach(0...59, id: \.self) { sec in
                                    Text(String(format: "%02d", sec))
                                        .tag(sec)
                                }
                            }
                            .frame(width: 60, height: 120)
                            .clipped()
                            .pickerStyle(.wheel)
                            Text("Seconds")
                                .font(.footnote)
                        }
                    }
                    
                }
                .frame(maxWidth: 340) // Helps center & control width
                .padding()
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 4)
                )
                
                // Mode checkboxes (only one can be selected)
                VStack(alignment: .leading, spacing: 16) {
                    modeRow(
                        label: "Hardcore mode",
                        modeKey: "Hard",
                        description: "Hardcore Mode locks you out of the app to ensure you stick to your goals. No distractions allowed!"
                    )
                    modeRow(
                        label: "Coach mode",
                        modeKey: "Coach",
                        description: "Your Peer’s role is to help you stay accountable. They’ll check in and offer guidance when you exceed your screen time!"
                    )
                    modeRow(
                        label: "Chill mode",
                        modeKey: "Chill",
                        description: "Not ready for Peer pressure? No problem! We’ll notify you when you’re nearing your time limit so you can stay on track."
                    )
                }
                .padding(.horizontal, 4)
                
                // Save Button
                Button(action: saveToFirebase) {
                    Text("Save")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                }
            }
            .padding()
            .onAppear {
                loadFromUserSettings()
            }
    }

    // Single checkbox row (but effectively radio button logic).
    @ViewBuilder
    private func modeRow(label: String, modeKey: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Tap on the icon to select the mode
                Image(systemName: selectedMode == modeKey ? "checkmark.square" : "square")
                    .onTapGesture {
                        selectedMode = modeKey
                    }
                Text(label)
                    .fontWeight(.semibold)
            }
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Load user settings
    private func loadFromUserSettings() {
        let settings = userSettingsManager.userSettings
        
        self.hours = settings.thresholdHour
        self.minutes = settings.thresholdMinutes
        self.selectedMode = settings.selectedMode
    }

    // MARK: - Save user settings to Firestore
    private func saveToFirebase() {
        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()
        
        // Keep a snapshot for comparison
        let old = userSettingsManager.userSettings
        let oldTotal = old.thresholdHour * 3600 + old.thresholdMinutes * 60
        let newTotal = hours * 3600 + minutes * 60
        
        // Reset streak if limit increased
        if newTotal > oldTotal || userSettingsManager.userSettings.startDailyStreakDate == nil {
            print("Streak start date reset due to increased threshold")
            userSettingsManager.userSettings.startDailyStreakDate = Date()
        }

        userSettingsManager.userSettings.thresholdHour = hours
        userSettingsManager.userSettings.thresholdMinutes = minutes
        userSettingsManager.userSettings.selectedMode = selectedMode
        
        userSettingsManager.saveSettings(userSettingsManager.userSettings)
    }
}
