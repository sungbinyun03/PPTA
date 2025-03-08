//
//  SignInOrSignUpView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

struct SignInOrSignUpView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showPhoneVerificationSheet = false
    
    var body: some View {
        VStack {
            RegistrationView()
                .environmentObject(viewModel)
            
            PageIndicator(page: 1)
                .padding(.bottom, 20)
        }
        // Check if user is authenticated but needs phone verification
        .onChange(of: viewModel.userSession) { _, newValue in
            if newValue != nil {
                // Check if the user needs phone verification
                if let currentUser = viewModel.currentUser, currentUser.phoneNumber == nil {
                    showPhoneVerificationSheet = true
                } else {
                    // If phone number exists or after verification, proceed to next step
                    coordinator.advance()
                }
            }
        }
        .sheet(isPresented: $showPhoneVerificationSheet) {
            PhoneVerificationView()
                .environmentObject(viewModel)
                .onDisappear {
                    // Only advance if verification was successful
                    if let currentUser = viewModel.currentUser, currentUser.phoneNumber != nil {
                        coordinator.advance()
                    }
                }
        }
    }
}
