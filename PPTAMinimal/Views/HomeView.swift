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
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    ProfileView()
                    devPrintoutSection
                    DashboardView()
                    reportSection
                    TraineeCoachView()
                }
                .padding(.top, 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .navigationBarHidden(true)
                // Present the ContactsPickerView sheet when needed
                .sheet(isPresented: $isContactsPickerPresented) {
                    ContactsPickerView(selectedContacts: $selectedContacts)
                }
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

    
    private var devPrintoutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dev Stuff")
                .font(.custom("SatoshiVariable-Bold_Light", size: 20))
            Button("Print unlock URL") {
                if
                  let childUID  = viewModel.currentUser?.id,
                  let link = UnlockService.makeUnlockURL(
                                childUID: childUID,
                                coachUID: "TEST_COACH")
                {
                    print("UNLOCK LINK →", link.absoluteString)
                    UIPasteboard.general.string = link.absoluteString
                }
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
                        if !previewMode {
                            ReportView(isMonitoring: false)
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
