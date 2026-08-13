import SwiftUI
import UIKit
import FamilyControls

struct EnableTrackingView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionGranted = false
    @State private var wasDenied = false
    @Environment(\.openURL) private var openURL

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

                // No skip: without Screen Time authorization the app cannot monitor, shield,
                // or report anything, so letting someone past here produces an account that
                // silently does nothing.
                if wasDenied {
                    VStack(spacing: 6) {
                        Text("Screen Time is required for PPTA to work.")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Open Settings") { openSettings() }
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(Color("primaryColor"))
                    }
                    .padding(.horizontal, 32)
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
        // Reflect the real authorization status rather than the fact that we asked. This
        // previously set `true` unconditionally, so a denial still advanced onboarding and
        // left the user marked complete with no authorization.
        permissionGranted = center.authorizationStatus == .approved
        wasDenied = !permissionGranted
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    EnableTrackingView(coordinator: OnboardingCoordinator())
}
