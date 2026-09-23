import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var showingAppleSignIn = false

    private let primaryColor = Color("primaryColor")

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 8) {
                Text("PPTA")
                    .font(.custom("BambiBold", size: 52))
                    .foregroundColor(primaryColor)
                Text("Peer Pressure The App")
                    .font(.custom("Satoshi-Variable", size: 15))
                    .foregroundColor(primaryColor.opacity(0.6))
            }

            Spacer()

            // Sign-in buttons
            VStack(spacing: 12) {
                // Google — matte house style (see the design system notes in CLAUDE.md).
                Button {
                    Task { await viewModel.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        Text("G")
                            .font(.custom("Satoshi-Variable", size: 18))
                            .fontWeight(.black)
                        Text("Continue with Google")
                            .font(.custom("Satoshi-Variable", size: 16))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(primaryColor.opacity(0.1))
                    )
                }

                // Apple — deliberately NOT matte. Sign in with Apple has its own branding rules
                // (approved fills, logo and wording), so it keeps the black treatment; only the
                // corner radius is matched to the rest of the app.
                Button {
                    showingAppleSignIn = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 18))
                        Text("Continue with Apple")
                            .font(.custom("Satoshi-Variable", size: 16))
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.black)
                    )
                }
                .sheet(isPresented: $showingAppleSignIn) {
                    AppleSignInButton()
                        .environmentObject(viewModel)
                }

                if let legalNotice {
                    Text(legalNotice)
                        .font(.custom("Satoshi-Variable", size: 12))
                        .foregroundColor(primaryColor.opacity(0.5))
                        .tint(primaryColor.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.top, 10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }

    /// "By continuing…" with only *Privacy Policy* tappable.
    ///
    /// Built as an `AttributedString` rather than markdown in a `Text` literal: interpolating the
    /// URL into a `LocalizedStringKey` stops the markdown link from being parsed, so the line
    /// renders as plain text with a visible URL in it.
    ///
    /// `nil` when `LegalLinks` has no usable URL, so a bad or unset link hides the notice instead
    /// of showing text that does nothing when tapped.
    private var legalNotice: AttributedString? {
        guard let url = LegalLinks.privacyPolicyURL else { return nil }
        var text = AttributedString("By continuing, you agree to our Privacy Policy.")
        if let range = text.range(of: "Privacy Policy") {
            text[range].link = url
            text[range].underlineStyle = .single
        }
        return text
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
