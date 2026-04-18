import SwiftUI

struct WelcomeView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("PPTA")
                    .font(.custom("BambiBold", size: 44))
                    .foregroundColor(Color("primaryColor"))
                Text("Peer Pressure The App")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 48)

            Image("onboarding-illustration-one 1")
                .resizable()
                .scaledToFit()
                .invertedForDarkMode()
                .padding(.horizontal, 24)
                .padding(.vertical, 32)

            VStack(spacing: 8) {
                Text("Set goals together.")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color("primaryColor"))
                Text("Hold each other accountable\nand stay focused.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 16) {
                PrimaryButton(title: "Get Started") {
                    coordinator.advance()
                }
                .padding(.horizontal, 24)

                PageIndicator(page: 0, length: 5)
                    .padding(.bottom, 36)
            }
        }
    }
}

#Preview {
    WelcomeView(coordinator: OnboardingCoordinator())
}
