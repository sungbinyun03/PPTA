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
            Text("Enable Notifs")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Bell icon from the provided design
            Image(systemName: "bell.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                .overlay(
                    // Hand ringing bell - simplified representation
                    Path { path in
                        path.move(to: CGPoint(x: 30, y: 70))
                        path.addLine(to: CGPoint(x: 15, y: 85))
                    }
                    .stroke(Color.black, lineWidth: 3)
                )
                .padding()
            
            Text("Allow Notifications")
                .font(.headline)
            
            Text("We'll use these to keep you informed!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                requestNotificationPermission()
            }) {
                Text(permissionGranted ? "Permission Granted!" : "Enable")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(permissionGranted ? Color.green : Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .cornerRadius(10)
            }
            .disabled(permissionGranted)
            
            Button(action: {
                coordinator.advance()
            }) {
                Text("I'll do this later")
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
            
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
