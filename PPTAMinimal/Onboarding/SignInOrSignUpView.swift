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
            // Adapt your existing LoginView here, but with navigation handled by the coordinator
            LoginView()
                .environmentObject(viewModel)
            
            // Page indicator
            HStack {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 10, height: 10)
                
                Circle()
                    .fill(Color(UIColor(red: 0.36, green: 0.42, blue: 0.26, alpha: 1.0)))
                    .frame(width: 10, height: 10)
                
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding(.bottom)
        }
        // Add navigation hooks to move through the onboarding flow
        .onChange(of: viewModel.userSession) { _, newValue in
            if newValue != nil {
                coordinator.advance()
            }
        }
    }
}
