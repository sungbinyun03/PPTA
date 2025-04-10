//
//  HomeView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI
import ContactsUI
import FamilyControls
import DeviceActivity

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    @State private var isReportViewPresented = false
    @State private var isContactsPickerPresented = false
    @State private var selectedContacts: [CNContact] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                ProfileView()
                weeklyStatsSection
                reportSection
                peerCoachesSection
            }
            .padding(.top, 0)
            .frame(maxWidth: .infinity, alignment: .leading)
            .navigationBarHidden(true)
            // Present the ContactsPickerView sheet when needed
            .sheet(isPresented: $isContactsPickerPresented) {
                ContactsPickerView(selectedContacts: $selectedContacts)
            }
        }
        .onAppear {
            // 1. Load user settings from Firestore on launch
            UserSettingsManager.shared.loadSettings { loadedSettings in
                DispatchQueue.main.async {
                    UserSettingsManager.shared.userSettings = loadedSettings
                }
                
                // 2. Always start monitoring once settings are loaded
                startAlwaysOnMonitoring(with: loadedSettings)
            }
        }
    }
    
    private var weeklyStatsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Weekly stats")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20))
            
            VStack(spacing: 10) {
                HStack(spacing: 14) {
                    Button("Daily Focus Average") { }
                    Button("Daily Focus Average") { }
                }
                .buttonStyle(StatButtonStyle())
                
                HStack(spacing: 14) {
                    Button("Time over limit") { }
                    Button("More Text") { }
                }
                .buttonStyle(StatButtonStyle())
            }
        }
    }
    
    private var reportSection: some View {
        VStack {
            Button(action: { isReportViewPresented.toggle() }) {
                VStack {
                    Text("Daily Screen Time")
                        .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                        .padding(.top, 5)
                        .padding(.bottom, 5)
                    
                    ScrollView {
                        ReportView(isMonitoring: false)
                            .frame(minHeight: 180, maxHeight: 220)
                    }
                    .frame(height: 210)
                }
                .padding(.vertical, 5)
                .frame(width: 333)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color(red: 0.247, green: 0.266, blue: 0.211), lineWidth: 4)
                )
            }
        }
        .sheet(isPresented: $isReportViewPresented) {
            ReportView(isMonitoring: false)
        }
    }
    
    private var peerCoachesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with title and a small add button always visible
            HStack {
                Text("Peer Coaches")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                Spacer()
                Button(action: {
                    isContactsPickerPresented = true
                }) {
                    Image(systemName: "plus.circle")
                        .font(.title2)
                }
            }
            
            // Only show the carousel if there are existing peer coaches.
            if !userSettingsManager.userSettings.peerCoaches.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(userSettingsManager.userSettings.peerCoaches, id: \.id) { coach in
                            VStack {
                                PeerCoachAvatarView(coach: coach)
                                    .frame(width: 50, height: 50)
                                Text("\(coach.givenName) \(coach.familyName)")
                                    .font(.caption)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }
    
    private func startAlwaysOnMonitoring(with settings: UserSettings) {
        let monitoringKey = "isMonitoringActive"
        let alreadyActive = UserDefaults.standard.bool(forKey: monitoringKey)
        if alreadyActive {
            NotificationManager.shared.sendNotification(
               title: "Monitoring already active",
               body: "Test"
            )
            print("Monitoring is already active, skipping re-start.")
            return
        }
        print("Loaded apps:", UserSettingsManager.shared.userSettings.applications.applicationTokens)
        print("Threshold:", settings.thresholdHour, settings.thresholdMinutes)
        // Otherwise, start fresh
        DeviceActivityManager.shared.startDeviceActivityMonitoring(
            appTokens: settings.applications,
            hour: settings.thresholdHour,
            minute: settings.thresholdMinutes
        ) { result in
            switch result {
            case .success:
                print("Always-on monitoring started successfully.")
                UserDefaults.standard.set(true, forKey: monitoringKey)
            case .failure(let error):
                print("Error starting monitoring: \(error)")
            }
        }
    }
}

// MARK: - Custom Button Style
struct StatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: 160, minHeight: 90)
            .background(Color(red: 0.4392, green: 0.4784, blue: 0.3843))
            .foregroundColor(.white)
            .cornerRadius(15)
    }
}

// MARK: - PeerCoach Avatar
struct PeerCoachAvatarView: View {
    let coach: PeerCoach
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.blue)
            Text(getInitials(for: coach))
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    private func getInitials(for coach: PeerCoach) -> String {
        let firstInitial = coach.givenName.first.map { String($0) } ?? ""
        let lastInitial = coach.familyName.first.map { String($0) } ?? ""
        return firstInitial + lastInitial
    }
}
