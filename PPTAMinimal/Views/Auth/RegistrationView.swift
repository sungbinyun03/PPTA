//
//  RegistrationView.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import _AuthenticationServices_SwiftUI

struct RegistrationView: View {
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreedToTerms = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: AuthViewModel
    
    private let primaryColor = Color("primaryColor")
    private let backgroundColor = Color(UIColor.systemBackground)
    private let textFieldBackground = Color("backgroundGray")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign up")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(primaryColor)
                
                Text("Make an account to get started")
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
            }
            .padding(.top, 20)
            
            // Form fields
            VStack(alignment: .leading, spacing: 20) {
                // Name field
                InputView(text: $name, title: "Name", placeholder: "John Doe")
                
                // Email field
                InputView(text: $email, title: "Phone Number", placeholder: "name@example.com")
                
                // Password field
                InputView(text: $password, title: "Password", placeholder: "********", isSecureField: true)
                
                // Terms and conditions
                HStack(alignment: .top, spacing: 12) {
                    Button(action: { agreedToTerms.toggle() }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(primaryColor, lineWidth: 1)
                                .frame(width: 24, height: 24)
                                .background(agreedToTerms ? primaryColor.opacity(0.1) : .clear)
                            
                            if agreedToTerms {
                                Image(systemName: "checkmark")
                                    .foregroundColor(primaryColor)
                                    .font(.system(size: 14, weight: .bold))
                            }
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("By signing up, I agree to ")
                            .foregroundColor(.secondary) +
                        Text("Peer Pressure's Terms and Conditions")
                            .foregroundColor(primaryColor)
                            .fontWeight(.medium)
                    }
                    .font(.caption)
                }
                
                // OR divider
                HStack {
                    VStack { Divider() }
                    Text("or")
                        .font(.footnote)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    VStack { Divider() }
                }
                .padding(.vertical, 8)
                
                // Auth buttons
                HStack(spacing: 20) {
                    Spacer()
                    
                    // Google button
                    Button(action: {
                        Task {
                            await viewModel.signInWithGoogle()
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(textFieldBackground)
                                .frame(width: 60, height: 60)
                            
                            Text("G")
                                .font(.title2)
                                .fontWeight(.black)
                                .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                        }
                    }
                    
                    // Apple Sign-In
                    Button(action: {
                        let appleSignInView = AppleSignInButton()
                            .environmentObject(viewModel)
                        
                        // Present the controller
                        let hostingController = UIHostingController(rootView: appleSignInView)
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootViewController = window.rootViewController {
                            rootViewController.present(hostingController, animated: true)
                        }
                    }) {
                        ZStack {
                            Circle()
                                .fill(textFieldBackground)
                                .frame(width: 60, height: 60)
                            
                            Image(systemName: "apple.logo")
                                .font(.title2)
                                .foregroundColor(.black)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Next button
            Button(action: {
                Task {
                    await viewModel.createUser(withEmail: email, password: password, name: name)
                }
            }) {
                Text("Next")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(formIsValid ? primaryColor : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(!formIsValid)
        }
        .padding(.horizontal)
        .background(backgroundColor)
        .padding(.bottom, 20)
    }
    
    var formIsValid: Bool {
        return !email.isEmpty
            && email.contains("@")
            && !password.isEmpty
            && password.count > 5
            && !name.isEmpty
            && agreedToTerms
    }
}

#Preview {
    RegistrationView()
        .environmentObject(AuthViewModel())
}
