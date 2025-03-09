//
//  EnableNotificationsView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI
import UserNotifications

struct EnableNotificationsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionRequested = false
    @State private var permissionGranted = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Enable Notifs")
                .font(.largeTitle)
                .fontWeight(.medium)
                .foregroundColor(Color("primaryColor"))
            
            Image("onboarding-illustration-notifs")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 240)
            
            Text("Allow Notifications")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(Color("primaryColor"))
            
            Text("We'll use these to keep you informed!")
                .font(.body)
                .foregroundColor(Color("primaryColor"))
                .padding(.bottom, 20)
            
            Spacer()
            
            Button(action: {
                coordinator.advance()
            }) {
                Text("I'll do this later")
                    .foregroundColor(.secondary)
            }
            
            PrimaryButton(title: "Enable", isDisabled: permissionGranted) {
                requestNotificationPermission()
            }
            
            PageIndicator(page: 4)
                .padding(.bottom, 20)
        }
        .padding()
        .onChange(of: permissionGranted) { _, newValue in
            if newValue {
                // Wait a moment to show the success state, then advance
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    coordinator.advance()
                }
            }
        }
    }
    
    private func requestNotificationPermission() {
        NotificationManager.shared.requestAuthorization()
        permissionGranted = true
    }
}

#Preview {
    EnableNotificationsView(coordinator: OnboardingCoordinator())
}
