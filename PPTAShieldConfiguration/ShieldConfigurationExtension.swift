//
//  ShieldConfigurationExtension.swift
//  PPTAShieldConfiguration
//
//  The lock screen a trainee hits when they open a blocked app. This is the highest-emotion
//  moment in PPTA, so it speaks as PPTA rather than as a generic iOS restriction.
//
//  It also does the one thing only this process can: read `localizedDisplayName` off the
//  token and hand it to the app through the App Group. See `ShieldSharedStore.swift`.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    // MARK: - Entry points

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        learn(application)
        return shield(subject: application.localizedDisplayName)
    }

    override func configuration(
        shielding application: Application,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        learn(application)
        learn(category)
        return shield(
            subject: application.localizedDisplayName,
            categoryName: category.localizedDisplayName
        )
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(subject: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        learn(category)
        return shield(subject: webDomain.domain, categoryName: category.localizedDisplayName)
    }

    // MARK: - Harvesting

    private func learn(_ application: Application) {
        guard let token = application.token else { return }
        if let name = application.localizedDisplayName {
            AppNameStore.record(token, name: name)
        }
        AppNameStore.noteBlockAttempt(for: token)
    }

    private func learn(_ category: ActivityCategory) {
        guard let token = category.token, let name = category.localizedDisplayName else { return }
        AppNameStore.record(token, name: name)
    }

    // MARK: - Appearance

    private func shield(subject: String?, categoryName: String? = nil) -> ShieldConfiguration {
        let context = ShieldContext.load()
        let coachLocked = context?.lockedByName?.isEmpty == false

        return ShieldConfiguration(
            backgroundBlurStyle: .dark,
            backgroundColor: Palette.background,
            icon: icon(coachLocked: coachLocked),
            title: ShieldConfiguration.Label(
                text: title(for: subject),
                color: .white
            ),
            subtitle: ShieldConfiguration.Label(
                text: subtitle(context: context, categoryName: categoryName),
                color: Palette.subtitle
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Close",
                color: .white
            ),
            primaryButtonBackgroundColor: Palette.button,
            // Only offered when the user actually has coaches — PPTAShieldAction handles the
            // tap. Passing nil omits the button entirely.
            secondaryButtonLabel: context?.hasCoaches == true
                ? ShieldConfiguration.Label(text: "Ask my coach for more time", color: .white)
                : nil
        )
    }

    private func title(for subject: String?) -> String {
        guard let subject, !subject.isEmpty else { return "This app is locked" }
        return "\(subject) is locked"
    }

    private func subtitle(context: ShieldContext?, categoryName: String?) -> String {
        var lines: [String] = []

        if let locker = context?.lockedByName, !locker.isEmpty {
            lines.append("\(locker) locked this.")
        } else if context?.isHardcore == true {
            lines.append("You hit your daily limit.")
        } else {
            lines.append("You've reached your daily limit.")
        }

        if let categoryName, !categoryName.isEmpty {
            lines.append("Part of your \(categoryName) limit.")
        }

        // Only shown when a streak is actually running. Note this makes no claim about the
        // streak surviving — a Hardcore cutoff resets it, and the reset lands here as 0.
        if let days = context?.streakDays, days > 0 {
            lines.append("You're \(days) day\(days == 1 ? "" : "s") into your streak.")
        }

        lines.append("Open PPTA to ask a coach for more time.")
        return lines.joined(separator: "\n")
    }

    private func icon(coachLocked: Bool) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .semibold)
        // A human locking you out and a timer locking you out are different feelings.
        let symbol = coachLocked ? "person.2.fill" : "lock.fill"
        return UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(.white, renderingMode: .alwaysOriginal)
    }
}

// MARK: - Palette

/// Asset-catalog colors are unavailable to extensions, so the brand palette is mirrored
/// here from `Assets.xcassets`. Keep in sync if the palette changes.
private enum Palette {
    /// `primaryColor` light (#44562E), used in **both** appearances on purpose: the dark
    /// variant (#8D9388) is far too light to carry white text. Slightly translucent so the
    /// blurred app shows through underneath — you can see what you're being held back from.
    static let background = UIColor(
        red: 68.0 / 255.0, green: 86.0 / 255.0, blue: 46.0 / 255.0, alpha: 0.93
    )

    /// `primaryButtonColor` (#707A62).
    static let button = UIColor(
        red: 112.0 / 255.0, green: 122.0 / 255.0, blue: 98.0 / 255.0, alpha: 1.0
    )

    static let subtitle = UIColor.white.withAlphaComponent(0.85)
}
