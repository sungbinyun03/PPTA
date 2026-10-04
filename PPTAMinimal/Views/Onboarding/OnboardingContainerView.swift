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
    /// Onboarding lives outside `TabNavigator`, which owns the app's only other banner mount, so
    /// anything `showInAppMessage` reports during the flow — e.g. the Firestore read behind
    /// `fetchUser()` failing on the phone step — would otherwise be published and never rendered.
    @ObservedObject private var notifications = NotificationManager.shared

    @State private var showPhoneVerificationSheet = false
    @State private var didConfigure = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()

                step
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: coordinator.isGoingBack ? .leading : .trailing)
                                .combined(with: .opacity),
                            removal: .move(edge: coordinator.isGoingBack ? .trailing : .leading)
                                .combined(with: .opacity)
                        )
                    )
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if coordinator.canGoBack {
                        Button {
                            coordinator.goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(Color("primaryColor"))
                        }
                    }
                }

                // No global Skip: it marked onboarding complete without granting Screen Time,
                // picking apps, or setting a limit, producing an account that looks set up but
                // can't monitor anything. Only the final step is skippable, and it says so.
            }
        }
        .overlay(alignment: .top) {
            if let banner = notifications.inAppBanner {
                InAppBannerView(title: banner.title, message: banner.body) {
                    notifications.inAppBanner = nil
                }
                .padding(.top, 8)
            }
        }
        .onAppear(perform: configureIfPossible)
        .onChange(of: authViewModel.currentUser) { _, _ in configureIfPossible() }
        .onChange(of: coordinator.currentStep) { _, step in
            if step == .completed {
                authViewModel.markOnboardingComplete()
            }
            // The phone number is what lets other people find this user by contact match, so it is
            // asked for at the step where it matters. Previously this sheet could appear over any
            // step — including Welcome — the moment `currentUser` loaded without a phone, with
            // `interactiveDismissDisabled(true)` making it an unskippable wall.
            // Returning users (reinstall / re-login) already verified, so they never see this.
            if step == .findCoach, (authViewModel.currentUser?.phoneNumber ?? "").isEmpty {
                showPhoneVerificationSheet = true
            }
        }
        .sheet(isPresented: $showPhoneVerificationSheet) {
            PhoneVerificationView()
                .environmentObject(authViewModel)
                .interactiveDismissDisabled(true)
        }
    }

    @ViewBuilder
    private var step: some View {
        switch coordinator.currentStep {
        case .intro:
            IntroKeyView(coordinator: coordinator)
        case .howItWorks:
            HowItWorksView(coordinator: coordinator)
        case .profile:
            CreateProfileView(coordinator: coordinator)
        case .appLimits:
            // Reuses the Settings App Limits screen in onboarding mode: "Save & Continue", always
            // enabled, no confirm alert, ensures Screen Time auth, marks onboarding complete, then
            // advances the flow. Returning users see their saved settings pre-filled.
            AppLimitsView(onboarding: true, onContinue: { coordinator.advance() })
        case .findCoach:
            FindCoachView(coordinator: coordinator)
        case .completed:
            EmptyView()
        }
    }

    /// Restores an abandoned run once the signed-in user is known.
    private func configureIfPossible() {
        guard !didConfigure, authViewModel.currentUser != nil else { return }
        didConfigure = true
        coordinator.configure()
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AuthViewModel())
}
