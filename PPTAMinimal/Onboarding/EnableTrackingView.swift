//
//  EnableTrackingView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI
import FamilyControls

struct EnableTrackingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionGranted = false
    
    var body: some View {
        VStack(spacing: 24) {
            Text("Enable Tracking")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // Tracking icon
            Image(systemName: "megaphone.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundColor(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                .padding()
            
            Text("Allow Screentime Tracking")
                .font(.headline)
            
            Text("We'll use this to help you stay focused!")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                requestScreenTimePermission()
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
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 8, height: 8)
                
                ForEach(0..<2) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
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
        permissionGranted = true
    }
}
