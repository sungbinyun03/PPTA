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
            Spacer()
            
            Text("Enable Tracking")
                .font(.largeTitle)
                .fontWeight(.medium)
                .foregroundColor(Color("primaryColor"))
            
            Image("onboarding-illustration-tracking")
                .resizable()
                .scaledToFit()
                .frame(width: 340, height: 250)
            
            Text("Allow Screentime Tracking")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(Color("primaryColor"))
            
            Text("We'll use this to help you stay focused!")
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
                requestScreenTimePermission()
            }
            
            PageIndicator(page: 3)
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

#Preview {
    EnableTrackingView(coordinator: OnboardingCoordinator())
}
