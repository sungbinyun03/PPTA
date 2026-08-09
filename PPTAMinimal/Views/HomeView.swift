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
    @State private var showPressureLevelInfo = false
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ProfileView(headerPart1: "Welcome Back, ", headerPart2: nil, subHeader: "Ready to lock in?")
                ScrollView {
                    VStack(spacing: 12) {
                        SetupCardView()
                        statusCard
                        reportSection
                        TraineeCoachView()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 12)
                .refreshable {
                    await withCheckedContinuation { continuation in
                        UserSettingsManager.shared.loadSettings { loadedSettings in
                            DispatchQueue.main.async {
                                UserSettingsManager.shared.userSettings = loadedSettings
                                Task { @MainActor in
                                    await UserSettingsManager.shared.applyPendingStatusIfNeeded()
                                    continuation.resume()
                                }
                            }
                        }
                    }
                }
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
    
    // MARK: - Status Banner

    @ViewBuilder
    private var statusCard: some View {
        let settings = userSettingsManager.userSettings
        if !settings.isTracking || !settings.hasViableAppLimits {
            let message = !settings.isTracking && !settings.hasViableAppLimits
                ? "Pressure Level is off and App Limits aren't set up. Head to Settings to get started."
                : !settings.isTracking
                    ? "Pressure Level is off. Enable Standard or Hardcore in Settings to start tracking."
                    : "App Limits aren't set up. Go to Settings → App Limits to pick apps and set a daily time limit."
            statusBanner(
                icon: "exclamationmark.triangle.fill",
                title: "Not Tracking",
                message: message,
                color: Color(.systemGray5),
                textColor: Color(.label)
            )
        } else {
            switch settings.traineeStatus {
            case .allClear:
                statusBanner(
                    icon: "checkmark.circle.fill",
                    title: "All Clear",
                    message: "You're within your limit and tracking properly.",
                    color: TraineeStatus.allClear.ringColor ?? .green
                )
            case .attentionNeeded:
                statusBanner(
                    icon: "exclamationmark.circle.fill",
                    title: "Limits Exceeded",
                    message: "You've hit your screen time limit. Your coaches have been notified and can lock your apps.",
                    color: TraineeStatus.attentionNeeded.ringColor ?? .red
                )
            case .cutOff:
                statusBanner(
                    icon: "lock.fill",
                    title: "Apps Locked",
                    message: settings.pressureLevel == .hardcore
                        ? "You hit your limit and your apps were auto-locked. Reach out to a coach to snooze the lock if you want more time."
                        : "A coach locked your apps. If you want more time, have a coach snooze the lock for you.",
                    color: TraineeStatus.cutOff.ringColor ?? Color(white: 0.25)
                )
            case .snoozedLock:
                statusBanner(
                    icon: "clock",
                    title: "Snooze Active",
                    message: "Your coach gave you 10 minutes. Apps re-lock when time's up.",
                    color: TraineeStatus.snoozedLock.ringColor ?? .blue
                )
            case .noStatus:
                EmptyView()
            }
        }
    }

    private func statusBanner(icon: String, title: String, message: String, color: Color, textColor: Color = .white) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(textColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("BambiBold", size: 15))
                    .foregroundColor(textColor)
                Text(message)
                    .font(.custom("Satoshi-Variable", size: 13))
                    .foregroundColor(textColor.opacity(0.85))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(color.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 24)
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

    private var streakLabel: String {
        let days = StreakCalculator.daysSince(
            start: userSettingsManager.userSettings.startDailyStreakDate,
            calendar: .current
        )
        guard userSettingsManager.userSettings.isTracking else { return "Daily Streak: Paused" }
        return "Daily Streak: \(days) day\(days == 1 ? "" : "s")"
    }

    private var reportSection: some View {
        Button(action: { isReportViewPresented.toggle() }) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Daily Screen Time")
                        .font(.custom("BambiBold", size: 22))
                        .foregroundColor(Color("primaryColor"))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color("primaryColor").opacity(0.5))
                }

                HStack(spacing: 6) {
                    Text(streakLabel.uppercased())
                        .font(.custom("Satoshi-Variable", size: 11))
                        .fontWeight(.semibold)
                        .tracking(1.2)
                        .foregroundColor(Color("primaryColor").opacity(0.6))
                    if !userSettingsManager.userSettings.isTracking {
                        Button { showPressureLevelInfo = true } label: {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.orange)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showPressureLevelInfo) {
                            Text("Go to Settings → Pressure Level to activate tracking. Without it, your status and streak won't update.")
                                .font(.subheadline)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(16)
                                .frame(width: 260)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }

                Group {
                    if !previewMode {
                        DeviceActivityReport(.init("Summary Ring"), filter: summaryFilter)
                    } else {
                        Text("Preview mode")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 215)

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
            .contains(DeviceActivityManager.dailyActivityName)
        let alreadyActive = flagSaysActive && systemSaysActive

        // If the user is not tracking (e.g. pressure level Off), ensure monitoring is not running.
        // Off means nothing stays armed, so this tears down any grace period too. Unconditional
        // because a grace period can outlive the daily activity — gating on `systemSaysActive`
        // would leave it armed after switching to Off. Stopping is idempotent.
        if settings.isTracking == false {
            DeviceActivityManager.shared.stopAllMonitoring()
            UserDefaults.standard.set(false, forKey: monitoringKey)
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
