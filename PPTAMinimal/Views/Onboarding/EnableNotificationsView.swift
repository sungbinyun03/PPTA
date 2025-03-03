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
                .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.26))
            
            // Bell icon from the provided design
            Image("onboarding-illustration-notifs")
                .resizable()
                .scaledToFit()
                .frame(width: 220, height: 240)
            
            Text("Allow Notifications")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.26))
            
            Text("We'll use these to keep you informed!")
                .font(.body)
                .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.26))
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
            
//            Button(action: {
//                requestNotificationPermission()
//            }) {
//                Text(permissionGranted ? "Permission Granted!" : "Enable")
//                    .fontWeight(.medium)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(permissionGranted ? Color.green : Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
//                    .cornerRadius(8)
//            }
//            .disabled(permissionGranted)
//            .padding(.bottom, 20)
            
            // Page indicator
            HStack {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 8, height: 8)
                
                Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
            }
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
