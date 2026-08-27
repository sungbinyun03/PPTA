//
//  ShieldActionExtension.swift
//  PPTAShieldAction
//
//  Handles taps on the PPTA lock screen's buttons.
//
//  Like the shield configuration extension, this process is short-lived and must stay free of
//  Firebase — see the header in `ShieldSharedStore.swift`. It cannot reach Firestore, so
//  "Ask my coach" drops a marker in the App Group and posts a local notification; the main app
//  files the real request on next foreground.
//

import ManagedSettings
import UserNotifications

class ShieldActionExtension: ShieldActionDelegate {

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        respond(to: action, completionHandler: completionHandler)
    }

    // MARK: - Shared handling

    private func respond(
        to action: ShieldAction,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            completionHandler(.close)

        case .secondaryButtonPressed:
            // A shield extension can't open the app or show UI. Post a notification whose tap opens
            // PPTA to Home, where the app prompts the trainee to pick a coach and request a snooze.
            // Nothing is sent from here — the request is made per-coach from that coach's profile.
            postHandoffNotification()
            // `.defer` keeps the shield up: nothing has been unlocked, and only a coach can change that.
            completionHandler(.defer)

        @unknown default:
            // Never `fatalError()` here (the Xcode template does): a crash in this process
            // takes the shield's buttons down with it.
            completionHandler(.close)
        }
    }

    /// The bridge back into the app: its tap opens PPTA (a shield extension can't launch the app
    /// itself). The body tells the trainee where to go — open a coach's profile and request a snooze.
    private func postHandoffNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Ask a coach for more time 🙏"
        content.body = "Open a coach's profile to request a snoozed lock from them."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: ShieldHandoff.askCoachIdentifier,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.5, repeats: false)
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("PPTAShieldAction: failed to post handoff notification: \(error)")
            }
        }
    }
}
