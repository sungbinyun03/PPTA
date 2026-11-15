//
//  ShieldActionExtension.swift
//  PPTAShieldAction
//
//  Handles taps on the PPTA lock screen's buttons.
//
//  Like the shield configuration extension, this process is short-lived and must stay free of
//  Firebase — see the header in `ShieldSharedStore.swift`. The shield has only "Got it", which
//  closes it.
//

import ManagedSettings

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
            // The shield no longer shows a secondary button; close if an old configuration did.
            completionHandler(.close)

        @unknown default:
            // Never `fatalError()` here (the Xcode template does): a crash in this process
            // takes the shield's buttons down with it.
            completionHandler(.close)
        }
    }
}
