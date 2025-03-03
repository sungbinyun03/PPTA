import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import _AuthenticationServices_SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var showingAppleSignIn = false
    @EnvironmentObject var viewModel: AuthViewModel
    
    private let primaryColor = Color(red: 0.36, green: 0.42, blue: 0.26)
    private let backgroundColor = Color(UIColor.systemBackground)
    private let textFieldBackground = Color(red: 0.92, green: 0.92, blue: 0.92)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Sign in")
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(primaryColor)
                
                Text("Welcome back")
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
            }
            .padding(.top, 20)
            
            // Form fields
            VStack(alignment: .leading, spacing: 20) {
                // Email field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email address")
                        .font(.body)
                        .foregroundColor(primaryColor)
                    
                    TextField("", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                }
                
                // Password field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.body)
                        .foregroundColor(primaryColor)
                    
                    SecureField("", text: $password)
                        .padding()
                        .background(textFieldBackground)
                        .cornerRadius(8)
                }
                
                // Forgot password
                HStack {
                    Spacer()
                    Button(action: {
                        // Forgot password action
                    }) {
                        Text("Forgot password?")
                            .font(.caption)
                            .foregroundColor(primaryColor)
                    }
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
                        showingAppleSignIn = true
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
                    .sheet(isPresented: $showingAppleSignIn) {
                        AppleSignInButton()
                            .environmentObject(viewModel)
                    }
                    
                    Spacer()
                }
                
                // Sign Up
                HStack {
                    Spacer()
                    
                    Text("Don't have an account?")
                        .foregroundColor(.secondary)
                    
                    NavigationLink {
                        RegistrationView()
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        Text("Sign up")
                            .fontWeight(.medium)
                            .foregroundColor(primaryColor)
                    }
                    
                    Spacer()
                }
                .font(.caption)
                .padding(.top)
            }
            
            Spacer()
            
            // Sign In button
            Button(action: {
                Task {
                    await viewModel.signIn(withEmail: email, password: password)
                }
            }) {
                Text("Sign In")
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
        .background(backgroundColor)
        .padding(.horizontal)
        .padding(.bottom, 20)
    }
    
    var formIsValid: Bool {
        return !email.isEmpty
            && email.contains("@")
            && !password.isEmpty
            && password.count > 5
    }
}

#Preview {
    NavigationView {
        LoginView()
            .environmentObject(AuthViewModel())
    }
}
