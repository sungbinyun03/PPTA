//
//  OnboardingContainerView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

struct OnboardingContainerView: View {
    /// When true, run the trimmed post-reinstall flow (re-grant Screen Time + confirm apps +
    /// re-set limit/pressure), pre-seeded from Firestore, instead of full first-time onboarding.
    var reconfigure: Bool = false
    @StateObject private var coordinator = OnboardingCoordinator()
    @EnvironmentObject var authViewModel: AuthViewModel

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
            if step == .findCoach, authViewModel.currentUser?.phoneNumber == nil {
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
        case .profile:
            CreateProfileView(coordinator: coordinator)
        case .chooseApps:
            ChooseAppsView(coordinator: coordinator)
        case .yourRules:
            YourRulesView(coordinator: coordinator)
        case .findCoach:
            FindCoachView(coordinator: coordinator)
        case .completed:
            EmptyView()
        }
    }

    /// Decides whether the profile step is part of this run, and restores an abandoned run.
    ///
    /// Re-evaluated while still on the first screen because `currentUser` loads asynchronously —
    /// a name arriving a moment after launch should still be able to drop the profile step. Once
    /// past `.intro` the flow shape is fixed, so the page indicator can't change length mid-run.
    private func configureIfPossible() {
        guard !didConfigure || coordinator.currentStep == .intro else { return }
        let name = authViewModel.currentUser?.name ?? ""
        let hasDisplayName = !name.isEmpty && name != "Unknown"
        didConfigure = authViewModel.currentUser != nil
        coordinator.configure(
            hasDisplayName: hasDisplayName,
            flow: reconfigure ? .reconfigure : .fresh,
            seed: reconfigure ? UserSettingsManager.shared.userSettings : nil
        )
    }
}

#Preview {
    OnboardingContainerView()
        .environmentObject(AuthViewModel())
}
