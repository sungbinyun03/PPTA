import SwiftUI
import UserNotifications

struct EnableNotificationsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var permissionGranted = false
    @State private var wasAsked = false

    var body: some View {
        VStack(spacing: 0) {
            Image("onboarding-illustration-notifs")
                .resizable()
                .scaledToFit()
                .invertedForDarkMode()
                .frame(maxHeight: 280)
                .padding(.horizontal, 32)
                .padding(.top, 48)

            VStack(spacing: 12) {
                Text("Stay in the loop")
                    .font(.custom("BambiBold", size: 28))
                    .foregroundColor(Color("primaryColor"))
                    .multilineTextAlignment(.center)

                Text("Get notified when your coaches take action or your trainees need your attention.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 12) {
                PrimaryButton(
                    title: permissionGranted ? "Enabled ✓" : "Enable Notifications",
                    isDisabled: permissionGranted
                ) {
                    Task { await requestNotificationPermission() }
                }
                .padding(.horizontal, 24)

                // Unlike Screen Time, the app still functions without notifications — it just
                // can't reach the user. Kept advanceable, but only after they've been asked,
                // so it isn't a one-tap bypass of the step.
                if wasAsked {
                    Button {
                        coordinator.advance()
                    } label: {
                        Text("Continue without notifications")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                PageIndicator(page: 3, length: 5)
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

    private func requestNotificationPermission() async {
        // Reflect what the user actually chose. This previously set `true` regardless, so a
        // denial auto-advanced and reported "Enabled ✓" for notifications that never arrive.
        let granted: Bool = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if let error { print("Notification permission error: \(error)") }
                    continuation.resume(returning: granted)
                }
        }
        permissionGranted = granted
        wasAsked = true
    }
}

#Preview {
    EnableNotificationsView(coordinator: OnboardingCoordinator())
}
