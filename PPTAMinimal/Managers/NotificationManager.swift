//
//  NotificationManager.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/12/25.
//

import UserNotifications
import SwiftUI

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    private init() {}

    struct InAppBanner: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let body: String
    }

    /// Lightweight in-app banner payload (not a system notification).
    @Published var inAppBanner: InAppBanner?

    /// One-shot: set when the user taps the shield's "Ask a coach for more time" notification.
    /// Lives here (not in a view) so a cold launch can set it before any view exists; the coaches
    /// section consumes it with `consumeCoachesPopoverRequest()`. Stamped so a tap that never
    /// finds a cut-off user doesn't pop the popover open much later.
    @Published private(set) var coachesPopoverRequestedAt: Date?

    func requestCoachesPopover() {
        coachesPopoverRequestedAt = Date()
    }

    /// Returns whether a recent request was pending, clearing it either way.
    func consumeCoachesPopoverRequest() -> Bool {
        defer { coachesPopoverRequestedAt = nil }
        guard let at = coachesPopoverRequestedAt else { return false }
        return Date().timeIntervalSince(at) < 15
    }
    
    func requestAuthorization() {
    
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notif authorization: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    //LOCAL
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        // Fire immediately (`trigger: nil`) — same as the extension's notifications. The old 2s
        // delay served no purpose and just made alerts feel laggy.
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule local notification: \(error)")
            }
        }
    }

    /// Shows a temporary in-app banner. Safe to call from any thread.
    func showInAppMessage(title: String, body: String, dismissAfter seconds: TimeInterval = 3.0) {
        DispatchQueue.main.async {
            let banner = InAppBanner(title: title, body: body)
            self.inAppBanner = banner
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
                if self.inAppBanner?.id == banner.id {
                    self.inAppBanner = nil
                }
            }
        }
    }
}
