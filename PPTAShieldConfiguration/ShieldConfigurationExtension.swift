//
//  ShieldConfigurationExtension.swift
//  PPTAShieldConfiguration
//
//  The lock screen a trainee hits when they open a blocked app. This is the highest-emotion
//  moment in PPTA, so it speaks as PPTA rather than as a generic iOS restriction: olive, matte
//  and calm (CLAUDE.md section 16), not an alarm. Only system fonts and layout are possible here.
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
        return shield(subject: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        shield(subject: webDomain.domain)
    }

    override func configuration(
        shielding webDomain: WebDomain,
        in category: ActivityCategory
    ) -> ShieldConfiguration {
        learn(category)
        return shield(subject: webDomain.domain)
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

    private func shield(subject: String?) -> ShieldConfiguration {
        let context = ShieldContext.load()
        let coachLocked = context?.lockedByName?.isEmpty == false

        return ShieldConfiguration(
            backgroundBlurStyle: .systemThinMaterial,
            backgroundColor: Palette.background,
            icon: icon(coachLocked: coachLocked),
            title: ShieldConfiguration.Label(
                text: title(for: subject, context: context),
                color: Palette.title
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Open Peer Pressure the App and request more time from your coaches.",
                color: Palette.subtitle
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Got it",
                color: .white
            ),
            primaryButtonBackgroundColor: Palette.button,
            // Only offered when the user actually has coaches — PPTAShieldAction handles the
            // tap. Passing nil omits the button entirely.
            secondaryButtonLabel: context?.hasCoaches == true
                ? ShieldConfiguration.Label(text: "Ask a coach for more time", color: Palette.title)
                : nil
        )
    }

    /// Names the reason. Copy uses first names only; the stored name is the coach's full name.
    private func title(for subject: String?, context: ShieldContext?) -> String {
        let target = (subject?.isEmpty == false) ? subject! : "this app"

        if let locker = context?.lockedByName, !locker.isEmpty {
            let first = locker.split(separator: " ").first.map(String.init) ?? locker
            return "\(first) locked \(target)"
        }
        if context?.isHardcore == true {
            return "Hardcore mode locked \(target)"
        }
        return "You've reached your limit on \(target)"
    }

    private func icon(coachLocked: Bool) -> UIImage? {
        let configuration = UIImage.SymbolConfiguration(pointSize: 44, weight: .medium)
        // A human locking you out and a timer locking you out are different feelings.
        let symbol = coachLocked ? "person.2.fill" : "lock.fill"
        return UIImage(systemName: symbol, withConfiguration: configuration)?
            .withTintColor(Palette.title, renderingMode: .alwaysOriginal)
    }
}

// MARK: - Palette

/// Asset-catalog colors are unavailable to extensions (the catalog isn't in this target), so the
/// brand palette is mirrored here from `Assets.xcassets` with light/dark dynamic providers.
/// Keep in sync if the palette changes.
private enum Palette {
    private static func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> UIColor {
        UIColor(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    private static func dynamic(light: UIColor, dark: UIColor) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? dark : light }
    }

    /// Soft olive-tinted matte (primaryColor #44562E at low strength over white / near-black),
    /// translucent so the blurred app still shows through.
    static let background = dynamic(
        light: rgb(0xF1F3EC, alpha: 0.92),
        dark: rgb(0x1B1F16, alpha: 0.92)
    )

    /// `primaryColor`: #44562E light, #8D9388 dark (its asset values). Title, icon, secondary button.
    static let title = dynamic(light: rgb(0x44562E), dark: rgb(0xC9D1BC))

    static let subtitle = dynamic(light: rgb(0x44562E, alpha: 0.75), dark: rgb(0xC9D1BC, alpha: 0.75))

    /// `primaryButtonColor` (#707A62, same in both appearances); carries white text.
    static let button = rgb(0x707A62)
}
