import SwiftUI
import GoogleSignIn
import GoogleSignInSwift
import _AuthenticationServices_SwiftUI
import FirebaseAuth

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject var viewModel: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                VStack(spacing: 24) {
                    InputView(text: $email,
                              title: "Email Address",
                              placeholder: "name@example.com")
                    .autocapitalization(.none)
                    
                    InputView(text: $password,
                              title: "Password",
                              placeholder: "Enter your password",
                              isSecureField: true)
                }
                .padding(.horizontal)
                .padding(.top, 12)
                
                // MARK: - Normal Sign-In Button
                Button {
                    Task {
                        try await viewModel.signIn(withEmail: email, password: password)
                    }
                } label: {
                    HStack {
                        Text("SIGN IN")
                            .fontWeight(.semibold)
                        Image(systemName: "arrow.right")
                    }
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                }
                .background(Color(.systemBlue))
                .disabled(!formIsValid)
                .opacity(formIsValid ? 1.0 : 0.5)
                .cornerRadius(10)
                .padding(.top, 24)
                
                HStack {
                    VStack { Divider() }
                    Text("or")
                    VStack { Divider() }
                }
                .padding(.vertical, 8)
                
                // MARK: - Google Sign-In Button
                Button(action: {
                    Task {
                        await viewModel.signInWithGoogle()
                    }
                }) {
                    HStack {
                        Image("google-icon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        
                        Text("Sign in with Google")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Color.primary)
                    .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                }
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray), lineWidth: 1)
                )
                .padding(.vertical, 4)
                
                // MARK: - Apple Sign-In Button
                SignInWithAppleButton { request in
                    viewModel.handleSignInWithAppleRequest(request)
                } onCompletion: { result in
                    viewModel.handleSignInWithAppleCompletion(result)
                }
                .frame(width: UIScreen.main.bounds.width - 32, height: 48)
                .cornerRadius(10)
                .padding(.vertical, 4)

                Spacer()
                
                NavigationLink {
                    RegistrationView()
                        .navigationBarBackButtonHidden(true)
                } label: {
                    HStack(spacing: 3) {
                        Text("Don't have an account?")
                        Text("Sign up")
                            .fontWeight(.bold)
                    }
                    .font(.system(size: 14))
                }
            }
            .padding(.horizontal)
            .background(Color(uiColor: .systemBackground))
        }
    }
}

extension LoginView: AuthenticationFormProtocol {
    var formIsValid: Bool {
        return !email.isEmpty
        && email.contains("@")
        && !password.isEmpty
        && password.count > 5
    }
}

#Preview {
    LoginView()
}
