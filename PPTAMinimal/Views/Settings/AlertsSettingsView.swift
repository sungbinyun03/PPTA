//
//  AlertsSettingsView.swift
//  PPTAMinimal
//
//  Settings → Alerts: choose how PPTA notifies you, Quiet or Alerts (see `Permissions.swift`).
//
//  What PPTA can and can't switch itself (iOS rules):
//  - Not asked → Quiet: silent request, no prompt.
//  - Not asked / Quiet → Alerts: iOS's prompt. "Don't Allow" there turns notifications off.
//  - Alerts → Quiet: only in iOS Settings (turn off Banners and Sounds for PPTA), so that option
//    explains and opens Settings.
//  - Off → anything: only iOS Settings.
//

import SwiftUI

struct AlertsSettingsView: View {
    @ObservedObject private var permissions = PermissionsMonitor.shared
    @Environment(\.scenePhase) private var scenePhase
    /// Set when the change can only be made in iOS Settings (`SettingsHelp`).
    @State private var settingsHelp: SettingsHelp?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(permissions.notifications.locksWorkWhileClosed
                     ? "Highly recommended to keep notifications on (even in quiet mode) so Peer Pressure works as intended."
                     : "Highly recommended to turn on notifications (even in quiet mode) so Peer Pressure works as intended.")
                    .font(.custom("Satoshi-Variable", size: 15))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if permissions.notifications == .denied {
                    offCard
                } else {
                    option(.alerts,
                           title: "Alerts",
                           detail: "Banners and sounds when your coaches or trainees need you.")
                    option(.quiet,
                           title: "Quiet",
                           detail: "No banners or sounds; notifications wait in Notification Centre.")
                }
            }
            .padding(24)
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
        .task { await permissions.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await permissions.refresh() } }
        }
        .alert(item: $settingsHelp) { help in
            Alert(title: Text(help.title), message: Text(help.message),
                  primaryButton: .default(Text("Open Settings")) { permissions.openNotificationSettings() },
                  secondaryButton: .cancel())
        }
    }

    // MARK: - Options

    private enum Choice { case alerts, quiet }

    private func isSelected(_ choice: Choice) -> Bool {
        switch choice {
        case .alerts: return permissions.notifications == .alerts
        case .quiet: return permissions.notifications.isQuiet
        }
    }

    private func choose(_ choice: Choice) {
        guard !isSelected(choice) else { return }
        switch (choice, permissions.notifications) {
        case (.alerts, .quietBySettings):
            settingsHelp = .toAlerts
        case (.alerts, _):
            Task { await permissions.requestAlerts() }
        case (.quiet, .notAsked):
            PermissionsMonitor.requestQuietIfNotAsked()
            Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                await permissions.refresh()
            }
        case (.quiet, _):
            settingsHelp = .toQuiet
        }
    }

    private func option(_ choice: Choice, title: String, detail: String) -> some View {
        let selected = isSelected(choice)
        return Button { choose(choice) } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(Color("primaryColor").opacity(selected ? 1 : 0.4))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.custom("Satoshi-Variable", size: 17))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(detail)
                        .font(.custom("Satoshi-Variable", size: 14))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color("primaryColor").opacity(selected ? 0.14 : 0.06))
            )
        }
        .buttonStyle(.plain)
    }

    private var offCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notifications are off")
                .font(.custom("Satoshi-Variable", size: 17))
                .fontWeight(.semibold)
            Text("Turn them on, then pick Alerts or Quiet here.")
                .font(.custom("Satoshi-Variable", size: 14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button { settingsHelp = .turnOn } label: {
                Text("Turn On")
                    .font(.custom("Satoshi-Variable", size: 14))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color("primaryColor")))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.1))
        )
    }
}

#Preview {
    NavigationStack { AlertsSettingsView() }
}
