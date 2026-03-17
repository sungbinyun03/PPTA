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
    @State private var showPhoneVerificationSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
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
                    HomeView() 
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
                                .foregroundColor(Color("primaryColor"))
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if coordinator.currentStep != .completed {
                        Button("Skip") {
                            if let uid = authViewModel.userSession?.uid {
                                UserDefaults.standard.set(true, forKey: "onboardingComplete_\(uid)")
                            }
                            coordinator.skipToMainApp()
                        }
                        .foregroundColor(Color("primaryColor"))
                    }
                }
            }
        }
        .onAppear {
            // Only show phone sheet when we know the user has no phone (currentUser already loaded)
            if authViewModel.userSession != nil,
               let user = authViewModel.currentUser,
               user.phoneNumber == nil {
                showPhoneVerificationSheet = true
            }
        }
        .onChange(of: authViewModel.currentUser) { _, newUser in
            guard authViewModel.userSession != nil else { return }
            if newUser?.phoneNumber != nil {
                showPhoneVerificationSheet = false
            } else if newUser != nil {
                showPhoneVerificationSheet = true
            }
        }
        .sheet(isPresented: $showPhoneVerificationSheet) {
            PhoneVerificationView()
                .environmentObject(authViewModel)
        }
        .onChange(of: coordinator.currentStep) { _, step in
            if step == .completed, let uid = authViewModel.userSession?.uid {
                UserDefaults.standard.set(true, forKey: "onboardingComplete_\(uid)")
            }
        }
    }
}
