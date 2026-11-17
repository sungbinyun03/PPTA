//
//  Permissions.swift
//  PPTAMinimal
//
//  The two permissions PPTA can't work without, and what the app does about each.
//
//  Notifications are ONE iOS permission with four states (`NotificationAccess`). "Quiet" is iOS's
//  provisional authorization: granted silently at launch to anyone never asked (no prompt), it
//  delivers pushes to Notification Centre only, and the notification service extension still runs,
//  so a coach's lock or extra time applies while PPTA is closed. Quiet can only be reached from
//  "not asked"; once someone answers iOS's prompt (or taps Turn Off on a quiet notification), only
//  iOS Settings can change it. iOS's own prompt appears once per install, so PPTA only shows it
//  after its own screen explains why (`PermissionsView`), never cold at launch.
//
//  Never required: App Review 4.5.4 forbids requiring push notifications, so every screen that asks
//  has "Not now". See docs/design/features/permissions.md.
//

import FamilyControls
import SwiftUI
import UserNotifications

/// Notification permission, as PPTA presents it.
enum NotificationAccess: Equatable {
    /// Never asked. Normally only until the launch requests quiet mode.
    case notAsked
    /// Provisional: delivered quietly to Notification Centre; the lock extension runs.
    case quiet
    /// Full alerts (banners, sounds, badge).
    case alerts
    /// Allowed, but the user turned off Banners and Sounds for PPTA in iOS Settings: quiet by their
    /// own choice. Only Settings can switch it back, and the launch reminder leaves it alone.
    case quietBySettings
    /// Turned off. Only iOS Settings can turn it back on.
    case denied

    /// `alertStyle` / `sound` matter only when allowed: iOS keeps the permission "authorized" when
    /// someone turns off Banners and Sounds in Settings, so that's how quiet-by-choice shows up.
    init(_ status: UNAuthorizationStatus, alertStyle: UNAlertStyle = .banner, sound: UNNotificationSetting = .enabled) {
        switch status {
        case .provisional: self = .quiet
        case .authorized, .ephemeral:
            self = (alertStyle == .none && sound != .enabled) ? .quietBySettings : .alerts
        case .denied: self = .denied
        case .notDetermined: self = .notAsked
        @unknown default: self = .notAsked
        }
    }

    /// Pushes reach the phone, so the lock extension can apply locks while PPTA is closed.
    var locksWorkWhileClosed: Bool { self == .quiet || self == .alerts || self == .quietBySettings }

    /// Quiet either way (iOS's provisional mode, or banners and sounds off in Settings).
    var isQuiet: Bool { self == .quiet || self == .quietBySettings }
}

/// Why PPTA is sending someone to iOS Settings (iOS won't let the app change it, or prompt again).
/// One wording for the permissions screen and Settings → Alerts.
enum SettingsHelp: Identifiable {
    /// Notifications off: iOS shows its prompt only once.
    case turnOn
    /// Alerts → Quiet.
    case toQuiet
    /// Quiet chosen in Settings → Alerts.
    case toAlerts

    var id: Self { self }

    var title: String {
        switch self {
        case .turnOn: return "Turn on notifications"
        case .toQuiet: return "Switch to Quiet"
        case .toAlerts: return "Turn on Alerts"
        }
    }

    var message: String {
        switch self {
        case .turnOn: return "Turn on Allow Notifications for PPTA in Settings."
        case .toQuiet: return "Turn off Banners and Sounds for PPTA in Settings."
        case .toAlerts: return "Turn on Banners and Sounds for PPTA in Settings."
        }
    }
}

/// What the permissions screen offers for the notifications row.
enum NotificationAction: Equatable {
    /// iOS's prompt (from not asked, or upgrading from quiet).
    case askForAlerts
    /// Denied: iOS won't prompt again; PPTA's page in Settings.
    case openSettings
    /// Nothing to do.
    case none

    init(_ access: NotificationAccess) {
        switch access {
        case .notAsked, .quiet: self = .askForAlerts
        // Already allowed: iOS won't prompt; banners and sounds go back on in Settings.
        case .denied, .quietBySettings: self = .openSettings
        case .alerts: self = .none
        }
    }
}

/// When the permissions screen is needed: Screen Time off, or notifications off. Quiet counts as on,
/// since pushes still arrive and the lock extension runs.
struct PermissionGap: Equatable {
    var notifications: NotificationAccess
    var screenTimeApproved: Bool

    var isEmpty: Bool { notifications.locksWorkWhileClosed && screenTimeApproved }

    /// Onboarding's rule: show the screen unless there's nothing left to offer, so every new user
    /// sees the option of full alerts. Quiet chosen in Settings is a deliberate answer.
    var nothingToOffer: Bool {
        (notifications == .alerts || notifications == .quietBySettings) && screenTimeApproved
    }
}

/// Live permission state for the views, refreshed on launch and whenever PPTA comes to the front
/// (the user may have just changed something in Settings).
@MainActor
final class PermissionsMonitor: ObservableObject {
    static let shared = PermissionsMonitor()

    @Published private(set) var notifications: NotificationAccess = .notAsked
    @Published private(set) var screenTimeApproved = AuthorizationCenter.shared.authorizationStatus == .approved
    /// Set once the launch reminder has been shown (or wasn't needed), so it appears at most once per
    /// app launch however many times `TabNavigator` is rebuilt.
    var checkedThisLaunch = false

    var gap: PermissionGap {
        PermissionGap(notifications: notifications, screenTimeApproved: screenTimeApproved)
    }

    private init() {}

    func refresh() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notifications = NotificationAccess(settings.authorizationStatus,
                                           alertStyle: settings.alertStyle,
                                           sound: settings.soundSetting)
        screenTimeApproved = AuthorizationCenter.shared.authorizationStatus == .approved
    }

    /// Launch: quiet mode for anyone never asked. iOS shows no prompt for a provisional request, and
    /// it changes nothing for someone who has already answered.
    nonisolated static func requestQuietIfNotAsked() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge, .provisional]) { _, error in
                if let error { print("Permissions: quiet request failed: \(error)") }
            }
    }

    /// iOS's real prompt, shown only after PPTA's own screen said why. From quiet, a "Don't Allow"
    /// turns notifications off entirely, which is why it sits behind that screen.
    func requestAlerts() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await refresh()
    }

    func requestScreenTime() async {
        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
        } catch {
            print("Permissions: Screen Time request failed: \(error)")
        }
        await refresh()
    }

    /// PPTA's notification page in iOS Settings, one toggle away from turning them back on.
    func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    /// PPTA's page in iOS Settings (Screen Time, if iOS won't show its prompt again).
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
