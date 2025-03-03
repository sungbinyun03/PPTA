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
    
    var body: some View {
        VStack {
            RegistrationView()
                .environmentObject(viewModel)
            
            PageIndicator(page: 1)
                .padding(.bottom, 20)
        }
        // Add navigation hooks to move through the onboarding flow
        .onChange(of: viewModel.userSession) { _, newValue in
            if newValue != nil {
                coordinator.advance()
            }
        }
    }
}
