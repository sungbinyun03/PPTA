import SwiftUI
import FamilyControls

struct EnableTrackingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionGranted = false

    var body: some View {
        VStack(spacing: 0) {
            Image("onboarding-illustration-tracking")
                .resizable()
                .scaledToFit()
                .invertedForDarkMode()
                .padding(.horizontal, 32)
                .padding(.top, 48)

            VStack(spacing: 12) {
                Text("Track screen time")
                    .font(.custom("BambiBold", size: 28))
                    .foregroundColor(Color("primaryColor"))
                    .multilineTextAlignment(.center)

                Text("We use Screen Time to monitor the apps you choose — so your coaches can keep you on track.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(
                    title: permissionGranted ? "Enabled ✓" : "Enable Screen Time",
                    isDisabled: permissionGranted
                ) {
                    Task { await requestScreenTimePermission() }
                }
                .padding(.horizontal, 24)

                Button {
                    coordinator.advance()
                } label: {
                    Text("I'll do this later")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                PageIndicator(page: 2, length: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
            }
        }
        .onChange(of: permissionGranted) { _, newValue in
            if newValue {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    coordinator.advance()
                }
            }
        }
    }

    private func requestScreenTimePermission() async {
        let center = AuthorizationCenter.shared
        if center.authorizationStatus != .approved {
            do {
                try await center.requestAuthorization(for: .individual)
            } catch {
                print("Failed to request screen time auth: \(error)")
            }
        }
        permissionGranted = true
    }
}

#Preview {
    EnableTrackingView(coordinator: OnboardingCoordinator())
}
