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
            MercyRequestStore.record()
            postHandoffNotification()
            // `.defer` keeps the shield up: nothing has actually been unlocked, and only a
            // coach can change that. Closing here would imply the request succeeded.
            completionHandler(.defer)

        @unknown default:
            // Never `fatalError()` here (the Xcode template does): a crash in this process
            // takes the shield's buttons down with it.
            completionHandler(.close)
        }
    }

    /// The bridge back into the app. The request isn't filed until the user opens PPTA, so
    /// this notification is doing real work, not just confirming.
    private func postHandoffNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Tap to ask your coach"
        content.body = "Open PPTA to send your request for more time."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "pptaMercyRequest",
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
