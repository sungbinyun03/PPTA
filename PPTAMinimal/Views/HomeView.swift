//
//  HomeView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI
import Combine
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
                    if userSettingsManager.userSettings.traineeStatus == .cutOff
                        && userSettingsManager.userSettings.pressureLevel == .hardcore {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.white)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Apps Locked")
                                    .font(.custom("BambiBold", size: 15))
                                    .foregroundColor(.white)
                                Text("You've hit your Hardcore limit for today.")
                                    .font(.custom("Satoshi-Variable", size: 13))
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                    }
                    DashboardView()
                    StreakBannerView()
                    reportSection
                    TraineeCoachView()
                }
                .padding(.top, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        /// Keeps Screen Time monitoring aligned with `userSettings` whenever it changes (Firestore load, Pressure / App Limits save, etc.). `onAppear` alone is not enough when Home stays under the stack after pushing Settings.
        .onReceive(userSettingsManager.$userSettings) { settings in
            guard !previewMode else { return }
            startAlwaysOnMonitoring(with: settings)
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

    
    private var summaryFilter: DeviceActivityFilter {
        let selection = userSettingsManager.userSettings.applications
        let todayInterval = Calendar.current.dateInterval(of: .day, for: .now) ?? DateInterval()
        if selection.applicationTokens.isEmpty && selection.categoryTokens.isEmpty {
            return DeviceActivityFilter(
                segment: .daily(during: todayInterval),
                users: .all,
                devices: .init([.iPhone, .iPad])
            )
        }
        return DeviceActivityFilter(
            segment: .daily(during: todayInterval),
            users: .all,
            devices: .init([.iPhone]),
            applications: selection.applicationTokens,
            categories: selection.categoryTokens
        )
    }

    private var reportSection: some View {
        Button(action: { isReportViewPresented.toggle() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("SCREEN TIME")
                        .font(.custom("Satoshi-Variable", size: 11))
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundColor(Color("primaryColor").opacity(0.6))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("primaryColor").opacity(0.5))
                }

                Text("Daily Screen Time")
                    .font(.custom("BambiBold", size: 22))
                    .foregroundColor(Color("primaryColor"))

                Group {
                    if !previewMode {
                        DeviceActivityReport(.init("Summary Ring"), filter: summaryFilter)
                    } else {
                        Text("Preview mode")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 170)

                HStack {
                    Spacer()
                    Text("Tap for full breakdown")
                        .font(.custom("Satoshi-Variable", size: 12))
                        .fontWeight(.medium)
                        .foregroundColor(Color("primaryColor").opacity(0.4))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color("primaryColor").opacity(0.4))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("primaryColor").opacity(0.07))
            )
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isReportViewPresented) {
            NavigationStack {
                ReportView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func startAlwaysOnMonitoring(with settings: UserSettings) {
        let monitoringKey = "isMonitoringActive"
        // Cross-check the persisted flag against the actual running activities so that
        // a device restart or OS-level suspension doesn't permanently block restarts.
        let flagSaysActive = UserDefaults.standard.bool(forKey: monitoringKey)
        let systemSaysActive = DeviceActivityCenter().activities
            .contains(DeviceActivityName("AppUsageMonitoring"))
        let alreadyActive = flagSaysActive && systemSaysActive

        // If the user is not tracking (e.g. pressure level Off), ensure monitoring is not running.
        if settings.isTracking == false {
            if systemSaysActive {
                DeviceActivityManager.shared.stopMonitoring()
                UserDefaults.standard.set(false, forKey: monitoringKey)
            }
            print("Tracking disabled; monitoring is not running.")
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
