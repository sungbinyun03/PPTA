import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showingAppleSignIn = false

    private let primaryColor = Color("primaryColor")
    private let backgroundGray = Color("backgroundGray")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 8) {
                Text("PPTA")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundColor(primaryColor)
                Text("Peer Pressure The App")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Sign-in buttons
            VStack(spacing: 12) {
                // Google
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        Text("G")
                            .font(.title3)
                            .fontWeight(.black)
                            .foregroundColor(Color(red: 0.2, green: 0.4, blue: 0.2))
                        Text("Continue with Google")
                            .font(.headline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(backgroundGray)
                    .cornerRadius(12)
                }

                // Apple
                Button {
                    showingAppleSignIn = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.title3)
                        Text("Continue with Apple")
                            .font(.headline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                }
                .sheet(isPresented: $showingAppleSignIn) {
                    AppleSignInButton()
                        .environmentObject(viewModel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
