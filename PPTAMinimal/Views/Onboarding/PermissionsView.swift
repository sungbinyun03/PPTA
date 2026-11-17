//
//  PermissionsView.swift
//  PPTAMinimal
//
//  Screen Time and notifications, explained before iOS asks. Two uses:
//  - Onboarding, the step after App Limits ("Next").
//  - The launch reminder (`TabNavigator`), shown over the app while either is missing ("Not now").
//
//  This screen is PPTA's own ask: iOS's notification prompt only appears once per install, so it is
//  shown only from here, after the why. Never required (App Review 4.5.4): there is always a way on.
//  States and rules live in `Permissions.swift`.
//

import SwiftUI

struct PermissionsView: View {
    enum Mode {
        /// Onboarding step: "Next" advances the flow.
        case onboarding
        /// Launch reminder: "Not now" closes it until the next launch.
        case reminder(onClose: () -> Void)
    }

    @ObservedObject var coordinator: OnboardingCoordinator
    let mode: Mode
    @ObservedObject private var permissions = PermissionsMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var settingsHelp: SettingsHelp?

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            title: "Keep the pressure on",
            message: "Two permissions are needed for the full Peer Pressure experience.",
            primaryTitle: primaryTitle,
            secondaryTitle: secondaryTitle,
            onSecondary: secondaryTitle == nil ? nil : close,
            onPrimary: primaryAction
        ) {
            VStack(spacing: 12) {
                screenTimeCard
                notificationsCard
            }
            .padding(.horizontal, 24)
        }
        .alert(item: $settingsHelp) { help in
            Alert(title: Text(help.title), message: Text(help.message),
                  primaryButton: .default(Text("Open Settings")) { permissions.openNotificationSettings() },
                  secondaryButton: .cancel())
        }
        .task {
            // Just asked during onboarding: no reminder again when the app opens straight after.
            if case .onboarding = mode { permissions.checkedThisLaunch = true }
            await permissions.refresh()
        }
        // Back from Settings (or from iOS's prompt): show what changed, and let the reminder close
        // itself once nothing is missing.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await permissions.refresh()
                if case .reminder = mode, permissions.gap.isEmpty { close() }
            }
        }
    }

    // MARK: - Buttons

    private var primaryTitle: String? {
        switch mode {
        case .onboarding: return "Next"
        case .reminder: return permissions.gap.isEmpty ? "Done" : nil
        }
    }

    private var secondaryTitle: String? {
        if case .reminder = mode, !permissions.gap.isEmpty { return "Not now" }
        return nil
    }

    private func primaryAction() {
        switch mode {
        case .onboarding: coordinator.advance()
        case .reminder: close()
        }
    }

    private func close() {
        if case .reminder(let onClose) = mode { onClose() }
    }

    // MARK: - Cards

    private var screenTimeCard: some View {
        PermissionCard(
            icon: "hourglass",
            title: "Screen Time",
            detail: permissions.screenTimeApproved
                ? "On."
                : "Lets PPTA track the apps you picked and lock them when you hit your limit.",
            isOn: permissions.screenTimeApproved,
            buttonTitle: permissions.screenTimeApproved ? nil : "Turn On"
        ) {
            Task { await permissions.requestScreenTime() }
        }
    }

    private var notificationsCard: some View {
        PermissionCard(
            icon: "bell.badge",
            title: "Notifications",
            detail: notificationsDetail,
            // Quiet counts as on (the button still offers banners and sounds).
            isOn: permissions.notifications.locksWorkWhileClosed,
            buttonTitle: notificationsButtonTitle
        ) {
            switch NotificationAction(permissions.notifications) {
            case .askForAlerts: Task { await permissions.requestAlerts() }
            case .openSettings:
                settingsHelp = permissions.notifications == .denied ? .turnOn : .toAlerts
            case .none: break
            }
        }
    }

    private var notificationsDetail: String {
        switch permissions.notifications {
        case .alerts:
            return "On."
        case .quiet:
            return "On, but quiet by default. Turn on Alerts to get banners and sounds."
        case .notAsked:
            return "Hear from your coaches and trainees as it happens."
        case .denied:
            return "Off. Highly recommended to turn on (even in quiet mode) so Peer Pressure works as intended."
        case .quietBySettings:
            return "On, but quiet: banners and sounds are off in Settings."
        }
    }

    private var notificationsButtonTitle: String? {
        switch NotificationAction(permissions.notifications) {
        case .askForAlerts: return "Turn On"
        case .openSettings: return "Turn On"
        case .none: return nil
        }
    }
}

/// One permission: icon, what it's for, and either its button or a green tick. Card styling per the
/// design system (primaryColor 10% fill, 12pt continuous corners), like How It Works.
private struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let isOn: Bool
    let buttonTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color("primaryColor"))
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color("primaryColor").opacity(0.12)))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.custom("Satoshi-Variable", size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    if isOn {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("primaryColor"))
                    }
                }
                Text(detail)
                    .font(.custom("Satoshi-Variable", size: 14))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let buttonTitle {
                    Button(action: action) {
                        Text(buttonTitle)
                            .font(.custom("Satoshi-Variable", size: 14))
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color("primaryColor")))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.1))
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Permissions (reminder)") {
    PermissionsView(coordinator: OnboardingCoordinator(), mode: .reminder(onClose: {}))
}
