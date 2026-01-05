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
    
    //CLOUD
    func sendPushNotification(title: String, body: String) {
        let peerCoaches = UserSettingsManager.shared.userSettings.peerCoaches
        let tokens = peerCoaches.compactMap { $0.fcmToken }
        let phoneNumbers = peerCoaches.filter { $0.fcmToken == nil }.map { $0.phoneNumber }

        let requestBody: [String: Any] = [
            "tokens": tokens,
            "phoneNumbers": phoneNumbers,
            "title": title,
            "body": body
        ]
        
        print("@@@@@ FIRING WITH:: \(requestBody)")

        guard let url = URL(string: "https://us-central1-ppta-sms.cloudfunctions.net/notify-peers") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending push notification: \(error)")
                return
            }
            print("Push notification sent successfully!")
        }.resume()
    }
}
