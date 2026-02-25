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
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
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
