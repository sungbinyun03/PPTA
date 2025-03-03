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
            // Existing RegistrationView
            RegistrationView()
                .environmentObject(viewModel)
            
            // Page indicator
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 8, height: 8)
                
                ForEach(0..<4) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
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
