//
//  HomeView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI
import FamilyControls
import DeviceActivity

struct HomeView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    @State private var isReportViewPresented = false
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ProfileView(headerPart1: "Welcome Back, ", headerPart2: nil, subHeader: "Ready to lock in?")
                    DashboardView()
                    StreakBannerView()
                    reportSection
                    TraineeCoachView()
                }
                .padding(.top, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear {
            if previewMode {
                seedPreviewData()
            } else {
                // 1. Load user settings from Firestore on launch
                UserSettingsManager.shared.loadSettings { loadedSettings in
                    DispatchQueue.main.async {
                        UserSettingsManager.shared.userSettings = loadedSettings
                        // Apply any pending status / streak updates that the
                        // DeviceActivity extension recorded while the app
                        // was not running.
                        Task { @MainActor in
                            print("HomeView.onAppear: applying pending extension updates (status)...")
                            await UserSettingsManager.shared.applyPendingStatusIfNeeded()
                            print("HomeView.onAppear: done applying pending extension updates.")
                        }
                    }
                    
                    // 2. Always start monitoring once settings are loaded
                    startAlwaysOnMonitoring(with: loadedSettings)
                }
            }
        }
    }
    
    private func seedPreviewData() {
        // Minimal fake user for AuthViewModel
        if viewModel.currentUser == nil {
            viewModel.currentUser = User(
                id: "preview-user",
                name: "Preview Name",
                email: "preview@example.com"
                // phoneNumber and fcmToken are optional; omit or set as needed
            )
        }

        // Seed settings to drive UI — order and labels per model definition
        UserSettingsManager.shared.userSettings = UserSettings(
            applications: .init(),              // FamilyActivitySelection()
            thresholdHour: 1,
            thresholdMinutes: 30,
            onboardingCompleted: true,
            peerCoaches: [
                .init(givenName: "Ada", familyName: "Lovelace", phoneNumber: "111", fcmToken: nil),
                .init(givenName: "Alan", familyName: "Turing", phoneNumber: "222", fcmToken: nil)
            ],
            coaches: [],
            trainees: []
            // startDailyStreakDate: nil // optional
        )

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
                        if !previewMode {
                            ReportView()
                                .frame(minHeight: 180, maxHeight: 220)
                        } else {
                            Text("Disabled during preview")
                        }
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
            ReportView()
        }
    }
    
    private func startAlwaysOnMonitoring(with settings: UserSettings) {
        let monitoringKey = "isMonitoringActive"
        let alreadyActive = UserDefaults.standard.bool(forKey: monitoringKey)
        
        // If the user paused tracking, ensure monitoring is not running.
        if settings.isTracking == false {
            if alreadyActive {
                DeviceActivityManager.shared.stopMonitoring()
                UserDefaults.standard.set(false, forKey: monitoringKey)
            }
            print("Tracking paused; monitoring is disabled.")
            return
        }
        
        if alreadyActive {
//            NotificationManager.shared.sendNotification(
//               title: "Monitoring already active",
//               body: "Test",
//               isLock: true
//            )
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

// MARK: - Streak Banner

struct StreakBannerView: View {
    @ObservedObject private var settingsMgr = UserSettingsManager.shared
    
    private var streakDays: Int {
        StreakCalculator.daysSince(
            start: settingsMgr.userSettings.startDailyStreakDate,
            calendar: .current
        )
    }
    
    private var isTracking: Bool {
        settingsMgr.userSettings.isTracking
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Daily Streak")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                
                if !isTracking {
                    Text("Tracking is paused")
                        .font(.headline)
                } else if streakDays > 0 {
                    Text("\(streakDays) day\(streakDays == 1 ? "" : "s") strong")
                        .font(.headline)
                } else {
                    Text("Streak starts today")
                        .font(.headline)
                }
            }
            
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("primaryButtonColor").opacity(0.15))
        )
        .padding(.horizontal, 24)
    }
}

// Allows for preview by disabling or replacing all the iPhone-only functionality
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        let auth = AuthViewModel()
        auth.currentUser = User(
            id: "preview-user",
            name: "Preview Name",
            email: "preview@example.com"
        )
        
        return HomeView(previewMode: true)
            .environmentObject(auth)
    }
}
