//
//  OnboardingContainerView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

struct OnboardingContainerView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            ZStack {
                switch coordinator.currentStep {
                case .welcome:
                    WelcomeView(coordinator: coordinator)
                case .signInOrSignUp:
                    SignInOrSignUpView(coordinator: coordinator)
                case .createProfile:
                    CreateProfileView(coordinator: coordinator)
                case .enableTracking:
                    EnableTrackingView(coordinator: coordinator)
                case .enableNotifications:
                    EnableNotificationsView(coordinator: coordinator)
                case .findFriends:
                    FindFriendsView(coordinator: coordinator)
                case .completed:
                    MainView() // Your existing main app view
                        .environmentObject(authViewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if coordinator.currentStep != .welcome && coordinator.currentStep != .completed {
                        Button(action: {
                            coordinator.goBack()
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coordinator.currentStep != .completed {
                        Button("Skip") {
                            coordinator.skipToMainApp()
                        }
                        .foregroundColor(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    }
                }
            }
        }
    }
}
