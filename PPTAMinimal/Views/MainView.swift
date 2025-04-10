import SwiftUI
import FamilyControls
import DeviceActivity
import Contacts
import ContactsUI


struct MainView: View {
    // MARK: - States
    @State private var selection = FamilyActivitySelection()
    @State private var isPickerPresented = false
    @ObservedObject var userSettingsManager = UserSettingsManager.shared
    
    
    // Threshold Time
    @State private var hours: Int = 1
    @State private var minutes: Int = 30
    @State private var showingTimePicker = false
    
    @State private var isMonitoring = false
    @State private var filter: DeviceActivityFilter?
    
    // Contacts
    @State private var showingContactPicker = false
    @State private var selectedContacts: [CNContact] = []
    
    // Authentication
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showPhoneVerificationSheet = false
    var body: some View {
        Group {
            if viewModel.userSession != nil {
                mainContent
            } else {
                LoginView()
            }
        }
    }
    private var mainContent: some View {
        NavigationView {
            VStack {
                ScrollView {
                    ProfileView().padding()
                    mainVStack
                        .onAppear(perform: loadInitialSettings)
                        .onChange(of: viewModel.currentUser) { _, newUser in
                            if let newUser = newUser, newUser.phoneNumber == nil {
                                showPhoneVerificationSheet = true
                            }
                        }
                        .sheet(isPresented: $showPhoneVerificationSheet) {
                            PhoneVerificationView().environmentObject(viewModel)
                        }
                        .padding()
                }
            }
            .navigationTitle("PPTA")
        }
    }
    
    private var mainVStack: some View {
        VStack(spacing: 24) {
            timeLimitDisplay
            monitoringButtons
            selectedAppsSection
            contactsSection
            activityReportLink
        }
    }
    
    private func loadInitialSettings() {
        requestScreenTimePermission()
        NotificationManager.shared.requestAuthorization()
        UserSettingsManager.shared.loadSettings { loadedSettings in
            self.selection = loadedSettings.applications
            self.hours = loadedSettings.thresholdHour
            self.minutes = loadedSettings.thresholdMinutes
        }
    }
    
    private var activityReportLink: some View {
        NavigationLink(destination: ReportView(isMonitoring: isMonitoring)) {
            Text("View Activity Report")
                .bold()
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
    }
}

// MARK:Subviews
extension MainView {
    
    private var timeLimitDisplay: some View {
        VStack {
            Text("Current Daily Limit")
                .font(.headline)
            
            HStack {
                Text("\(hours)h \(minutes)m")
                    .font(.system(size: 32, weight: .bold))
                
                Button(action: {
                    showingTimePicker.toggle()
                }) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.blue)
                }
                .padding(.leading, 8)
            }
        }
        .sheet(isPresented: $showingTimePicker) {
            timePickerSheet
        }
    }
    
    private var timePickerSheet: some View {
        VStack(spacing: 16) {
            Text("Set Daily Time Limit")
                .font(.title2)
                .padding(.top)
            
            HStack(spacing: 20) {
                Picker("Hours", selection: $hours) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour) hr").tag(hour)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 100, height: 150)
                
                Picker("Minutes", selection: $minutes) {
                    ForEach(0..<60, id: \.self) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                .frame(width: 100, height: 150)
            }
            
            Button("Done") {
                showingTimePicker = false
            }
            .padding(.bottom, 20)
        }
    }
    
    private var monitoringButtons: some View {
        HStack(spacing: 20) {
            Button(action: {
                startMonitoring()
            }) {
                Text(isMonitoring ? "Monitoring..." : "Start Monitoring")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMonitoring ? Color.gray : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isMonitoring)
            
            Button(action: {
            }) {
                Text("Stop")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isMonitoring ? Color.red : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(!isMonitoring)
        }
    }
    
    private var selectedAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Selected Apps")
                .font(.headline)
            
            Button(action: {
                isPickerPresented = true
            }) {
                Label("Pick Apps", systemImage: "plus.app.fill")
                    .padding(8)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
            
            // Display selected apps
            if selection.applicationTokens.isEmpty, selection.categoryTokens.isEmpty {
                Text("No apps selected yet.")
                    .foregroundColor(.secondary)
            } else {
                VStack {
                    ForEach(Array(selection.applicationTokens.enumerated()), id: \.element) { index, token in
                        HStack(alignment: .center) {
                            Label(token)   // or a custom label showing token info
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        
                        if index < selection.applicationTokens.count - 1 {
                            Divider()
                        }
                    }
                    ForEach(Array(selection.categoryTokens.enumerated()), id: \.element) { index, token in
                        HStack(alignment: .center) {
                            Label(token)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        
                        if index < selection.categoryTokens.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Peer Coaches")
                .font(.headline)
            
            Button(action: {
                showingContactPicker = true
            }) {
                Label("Select Contacts", systemImage: "person.crop.circle.badge.plus")
                    .padding(8)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactsPickerView(selectedContacts: $selectedContacts)
            }
            let peerCoaches = userSettingsManager.userSettings.peerCoaches
            if peerCoaches.isEmpty {
                Text("No peer coaches selected.")
                    .foregroundColor(.secondary)
            } else {
                ForEach(peerCoaches, id: \.id) { coach in
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .padding(.trailing, 8)

                        VStack(alignment: .leading) {
                            Text("\(coach.givenName) \(coach.familyName)")
                                .font(.body)
                            Text(coach.phoneNumber)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }

        }
    }
}

// MARK: Logic Functions
extension MainView {
    
    private func requestScreenTimePermission() {
        let center = AuthorizationCenter.shared
        if center.authorizationStatus != .approved {
            Task {
                do {
                    try await center.requestAuthorization(for: .individual)
                    print("Requested FamilyControls/ScreenTime permission.")
                } catch {
                    print("Failed to request screen time auth: \(error)")
                }
            }
        } else {
            print("Already approved for Screen Time.")
        }
    }
    
    private func startMonitoring() {
        isMonitoring = true
        
        // Construct and Save new UserSettings
        let newUserSettings = UserSettings(
            applications: selection,
            thresholdHour: hours,
            thresholdMinutes: minutes,
            onboardingCompleted: true,
            peerCoaches: userSettingsManager.userSettings.peerCoaches
        )
        
        UserSettingsManager.shared.saveSettings(newUserSettings)
        
        DeviceActivityManager.shared.startDeviceActivityMonitoring(
            appTokens: selection,
            hour: hours,
            minute: minutes
        ) { result in
            switch result {
            case .success:
                print("Monitoring started successfully.")
            case .failure(let error):
                print("Error starting monitoring: \(error)")
                isMonitoring = false
            }
        }
    }

}
