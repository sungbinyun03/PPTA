//
//  WelcomeView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            HStack(spacing: 8) {
                Text("Welcome!")
                    .font(.largeTitle)
                    .fontWeight(.medium)
                    .foregroundColor(Color("primaryColor"))
                
                Text("👋")
                    .font(.largeTitle)
            }
            .padding(.bottom, 30)
            
            ZStack {
                Circle()
                    .stroke(Color.black, lineWidth: 1)
                    .frame(width: 260, height: 260)
                
                Image("onboarding-illustration-one")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
            }
            .padding(.bottom, 40)
            
            Text("Set goals together")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(Color("primaryColor"))
            
            Text("Stay focused with friends")
                .font(.body)
                .foregroundColor(Color("primaryColor"))
                .padding(.bottom, 20)
            
            Spacer()
            
            PrimaryButton(title: "Get Started") {
                coordinator.advance()
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            
            // Page indicators
            HStack(spacing: 8) {
                Circle()
                    .fill(Color("primaryColor"))
                    .frame(width: 8, height: 8)
                
                ForEach(0..<5) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 20)
        }
        .padding()
    }
}

#Preview {
    WelcomeView(coordinator: OnboardingCoordinator())
}
