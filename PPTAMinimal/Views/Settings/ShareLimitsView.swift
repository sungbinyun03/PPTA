//
//  ShareLimitsView.swift
//  PPTAMinimal
//
//  Lets a trainee hand their coaches a readable summary of the rules they're playing by.
//

import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings

// MARK: - Report card

/// The shareable "these are my rules" card.
///
/// Two modes exist because of how `FamilyActivitySelection` guards app identities. It holds
/// opaque tokens, and the only guaranteed way to draw one is `Label(token)`, which the system
/// renders out of process — content `ImageRenderer` cannot capture (verified: it draws a
/// placeholder row, not the app). So `.screenshot` uses those labels, since a real screenshot
/// always captures every name, while `.export` prints the names harvested by the shield
/// extension via `AppNameStore` and summarizes the rest as a count.
struct LimitsReportCard: View {
    enum Mode {
        /// On-screen: real app names via `Label(token)`. Only a screenshot captures these.
        case screenshot
        /// Rendered to PDF/PNG: app identities collapse to a count.
        case export
    }

    let mode: Mode
    let userName: String
    let generatedAt: Date

    private let profileImageURL: URL?
    private let thresholdHour: Int
    private let thresholdMinutes: Int
    private let pressureLevel: PressureLevel
    private let isTracking: Bool
    private let coachCount: Int
    private let streakDays: Int
    /// Flattened once at init: `FamilyActivitySelection` stores tokens in sets, and a fresh
    /// map on every render could hand `ForEach` a different order each pass.
    private let monitoredItems: [MonitoredItem]

    /// Apps the user kept trying to open *after* being locked out — a craving signal that
    /// DeviceActivity can't provide, since it only reports usage. Unlike app names, this is
    /// plain text, so it survives into the exported PDF.
    struct ResistedApp: Hashable {
        let name: String
        let attempts: Int
    }

    private let resistedApps: [ResistedApp]

    /// Names learned by the shield extension (see `AppNameStore`).
    ///
    /// The app cannot resolve these itself, and `ImageRenderer` cannot capture `Label(token)`,
    /// so the export prints the names harvested so far and summarizes the rest as a count.
    /// Coverage grows as the user hits lock screens, so this is expected to be partial.
    private let exportNames: [String]
    private let hiddenApps: Int
    private let hiddenCategories: Int

    init(mode: Mode, userName: String, settings: UserSettings, generatedAt: Date = Date()) {
        self.mode = mode
        self.userName = userName
        self.generatedAt = generatedAt
        self.profileImageURL = settings.profileImageURL
        self.thresholdHour = settings.thresholdHour
        self.thresholdMinutes = settings.thresholdMinutes
        self.pressureLevel = settings.pressureLevel
        self.isTracking = settings.isTracking
        self.coachCount = settings.coachIds.count
        self.streakDays = StreakCalculator.daysSince(start: settings.startDailyStreakDate)
        self.monitoredItems = settings.applications.applicationTokens.map(MonitoredItem.app)
            + settings.applications.categoryTokens.map(MonitoredItem.category)

        var names: [String] = []
        var unresolvedApps = 0
        var unresolvedCategories = 0
        for token in settings.applications.applicationTokens {
            if let name = AppNameStore.name(for: token) {
                names.append(name)
            } else {
                unresolvedApps += 1
            }
        }
        for token in settings.applications.categoryTokens {
            if let name = AppNameStore.name(for: token) {
                names.append(name)
            } else {
                unresolvedCategories += 1
            }
        }
        self.exportNames = names
        self.hiddenApps = unresolvedApps
        self.hiddenCategories = unresolvedCategories

        var resisted: [ResistedApp] = []
        for token in settings.applications.applicationTokens {
            guard let name = AppNameStore.name(for: token) else { continue }
            let attempts = AppNameStore.blockAttempts(for: token)
            guard attempts > 0 else { continue }
            resisted.append(ResistedApp(name: name, attempts: attempts))
        }
        self.resistedApps = Array(
            resisted.sorted { $0.attempts > $1.attempts }.prefix(3)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            limitBlock
            statTiles
            monitoringBlock
            if !resistedApps.isEmpty { resistedBlock }
            footer
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color("primaryColor").opacity(0.15), lineWidth: 1.5)
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 12) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(userName)
                    .font(.custom("BambiBold", size: 20))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(generatedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.custom("Satoshi-Variable", size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 8)
            Text("PPTA")
                .font(.custom("BambiBold", size: 16))
                .foregroundColor(Color("primaryColor").opacity(0.7))
        }
    }

    @ViewBuilder
    private var avatar: some View {
        switch mode {
        case .screenshot:
            InitialsProfilePicView(name: userName, profilePicUrl: profileImageURL?.absoluteString, size: 44)
        case .export:
            // AsyncImage has no chance to resolve during ImageRenderer's synchronous pass,
            // so exports always draw the deterministic initials circle.
            InitialsProfilePicView(name: userName, profilePicUrl: nil, size: 44)
        }
    }

    // MARK: Daily limit

    private var limitBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            kicker("My daily limit")
            Text(limitText)
                .font(.custom("BambiBold", size: 40))
                .foregroundColor(Color("primaryColor"))
            Text("across all monitored apps")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
        }
    }

    private var limitText: String {
        if thresholdHour == 0 && thresholdMinutes == 0 { return "Not set" }
        var parts: [String] = []
        if thresholdHour > 0 { parts.append("\(thresholdHour)h") }
        if thresholdMinutes > 0 { parts.append("\(thresholdMinutes)m") }
        return parts.joined(separator: " ")
    }

    // MARK: Stat tiles

    private var statTiles: some View {
        HStack(spacing: 8) {
            statTile(label: "Pressure", value: pressureLevel.rawValue, tint: pressureTint)
            statTile(label: "Streak", value: streakText, tint: .primary)
            statTile(label: "Coaches", value: "\(coachCount)", tint: .primary)
        }
    }

    private func statTile(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            Text(label.uppercased())
                .font(.custom("Satoshi-Variable", size: 9.5))
                .fontWeight(.semibold)
                .tracking(0.8)
                .foregroundColor(Color("primaryColor").opacity(0.6))
            Text(value)
                .font(.custom("BambiBold", size: 17))
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.07))
        )
    }

    /// Mirrors the colors PressureLevelView uses for each tier, so the level reads the same
    /// way it does on the screen where it was chosen.
    private var pressureTint: Color {
        switch pressureLevel {
        case .off:       return .secondary
        case .standard:  return Color("primaryButtonColor")
        case .hardcore:  return Color("primaryColor")
        }
    }

    /// Matches HomeView's streak label: a paused tracker never advertises a live streak.
    private var streakText: String {
        guard isTracking else { return "Paused" }
        return "\(streakDays) day\(streakDays == 1 ? "" : "s")"
    }

    // MARK: Monitored apps

    private var monitoringBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            kicker(monitoredCount > 0 ? "Monitoring (\(monitoredCount))" : "Monitoring")
            switch mode {
            case .screenshot: appList
            case .export:     exportList
            }
        }
    }

    enum MonitoredItem: Hashable {
        case app(ApplicationToken)
        case category(ActivityCategoryToken)
    }

    private var monitoredCount: Int { monitoredItems.count }

    private var appList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if monitoredItems.isEmpty {
                emptyRow
            } else {
                ForEach(Array(monitoredItems.indices), id: \.self) { index in
                    if index > 0 { Divider() }
                    monitoredRow(monitoredItems[index])
                }
            }
        }
        .background(well)
    }

    @ViewBuilder
    private func monitoredRow(_ item: MonitoredItem) -> some View {
        HStack(spacing: 10) {
            switch item {
            case .app(let token):      Label(token)
            case .category(let token): Label(token)
            }
            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
    }

    private var hiddenCount: Int { hiddenApps + hiddenCategories }

    /// Export list: every name iOS resolved, plus one summary row for whatever it withheld.
    private var exportList: some View {
        VStack(alignment: .leading, spacing: 0) {
            if monitoredItems.isEmpty {
                emptyRow
            } else {
                ForEach(Array(exportNames.indices), id: \.self) { index in
                    if index > 0 { Divider() }
                    exportNameRow(exportNames[index])
                }
                if hiddenCount > 0 {
                    if !exportNames.isEmpty { Divider() }
                    hiddenRow
                }
            }
        }
        .background(well)
    }

    private func exportNameRow(_ name: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "app.fill")
                .font(.system(size: 14))
                .foregroundColor(Color("primaryColor").opacity(0.7))
            Text(name)
                .font(.custom("Satoshi-Variable", size: 14))
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
    }

    private var hiddenRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "apps.iphone")
                .font(.system(size: 13))
                .foregroundColor(Color("primaryColor").opacity(0.6))
            Text(hiddenText)
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .frame(height: 40)
        .padding(.horizontal, 12)
    }

    private var hiddenText: String {
        var parts: [String] = []
        if hiddenApps > 0 { parts.append("\(hiddenApps) app\(hiddenApps == 1 ? "" : "s")") }
        if hiddenCategories > 0 {
            parts.append("\(hiddenCategories) categor\(hiddenCategories == 1 ? "y" : "ies")")
        }
        let subject = parts.joined(separator: " + ")
        // No mechanism talk: users don't need to know names are learned at lock screens,
        // and any honest explanation of it reads strangely on a shared report.
        return exportNames.isEmpty ? "\(subject) monitored" : "+ \(subject) more"
    }

    private var emptyRow: some View {
        Text("No apps selected yet.")
            .font(.custom("Satoshi-Variable", size: 13))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 44)
            .padding(.horizontal, 12)
    }

    // MARK: Most resisted

    private var resistedBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            kicker("Most resisted this week")
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(resistedApps.indices), id: \.self) { index in
                    if index > 0 { Divider() }
                    HStack(spacing: 10) {
                        Text(resistedApps[index].name)
                            .font(.custom("Satoshi-Variable", size: 14))
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text("\(resistedApps[index].attempts) opens")
                            .font(.custom("BambiBold", size: 14))
                            .foregroundColor(Color("primaryColor"))
                    }
                    .frame(height: 36)
                    .padding(.horizontal, 12)
                }
            }
            .background(well)
        }
    }

    // MARK: Footer & shared bits

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "flame.fill")
                .font(.system(size: 10))
            Text("Hold me accountable · PPTA")
                .font(.custom("Satoshi-Variable", size: 11))
                .fontWeight(.medium)
        }
        .foregroundColor(Color("primaryColor").opacity(0.5))
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("Satoshi-Variable", size: 11))
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundColor(Color("primaryColor").opacity(0.6))
    }

    private var well: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color("primaryColor").opacity(0.05))
    }
}

// MARK: - Share page

struct ShareLimitsView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @ObservedObject private var settingsMgr = UserSettingsManager.shared

    /// Card width used for exports. Fixed so the PDF/PNG never depend on device width.
    private static let exportCardWidth: CGFloat = 360
    private static let exportPageMargin: CGFloat = 32

    @State private var pdfURL: URL?
    @State private var pngURL: URL?
    @State private var showSetupWarning = false
    /// Stamped once per visit so the card and its exports agree on the date.
    @State private var generatedAt = Date()

    private var userName: String { viewModel.currentUser?.name ?? "PPTA User" }
    private var canShare: Bool { settingsMgr.userSettings.hasViableAppLimits }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Share My Limits")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Divider()

                LimitsReportCard(
                    mode: .screenshot,
                    userName: userName,
                    settings: settingsMgr.userSettings,
                    generatedAt: generatedAt
                )

                screenshotTip
                shareWithCoachesToggle
                shareButtons
                privacyNote

                Spacer(minLength: 0)
            }
            .padding()
        }
        .appAlert(
            isPresented: $showSetupWarning,
            title: "Set up App Limits first",
            message: "Pick at least one app and set a daily time limit in App Limits, then come back to share them."
        )
        // Regenerating here (rather than in `.task`) also covers the user editing their
        // limits in another tab while this page stays in the navigation stack.
        .onReceive(settingsMgr.$userSettings) { settings in
            // Use the published value, not `settingsMgr.userSettings`: @Published emits in
            // willSet, so re-reading the property here would still yield the previous value.
            regenerateExports(for: settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            NotificationManager.shared.showInAppMessage(
                title: "Screenshot saved",
                body: "Send it to your coaches so they know your rules."
            )
        }
    }

    // MARK: Page sections

    private var screenshotTip: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .foregroundColor(Color("primaryColor"))
            Text("Screenshot this page to share your limits with your app names visible.")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(Color("primaryColor"))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color("primaryColor").opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Opt-in for mirroring app names to coaches. Off by default: this uploads the user's app
    /// list, which is a different decision from monitoring it on-device.
    private var shareWithCoachesToggle: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { settingsMgr.userSettings.shareAppNamesWithCoaches },
                set: { newValue in
                    Task { @MainActor in
                        UserSettingsManager.shared.update { $0.shareAppNamesWithCoaches = newValue }
                    }
                }
            )) {
                Text("Show my coaches which apps I'm locking")
                    .font(.custom("Satoshi-Variable", size: 14))
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .tint(Color("primaryColor"))

            Text("Your coaches see these on your profile. Turning this off removes them.")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.07))
        )
    }

    @ViewBuilder
    private var shareButtons: some View {
        VStack(spacing: 12) {
            if canShare, let pdfURL {
                ShareLink(item: pdfURL) { primaryLabel("Share as PDF") }
                    .buttonStyle(.plain)
            } else {
                Button { showSetupWarning = true } label: { primaryLabel("Share as PDF", disabled: true) }
                    .buttonStyle(.plain)
            }

            if canShare, let pngURL {
                ShareLink(item: pngURL) { secondaryLabel("Share as Image") }
                    .buttonStyle(.plain)
            } else {
                Button { showSetupWarning = true } label: { secondaryLabel("Share as Image", disabled: true) }
                    .buttonStyle(.plain)
            }
        }
    }

    private var privacyNote: some View {
        Text("Screenshots always show your full app list. Shared files include your limit, streak, and the apps PPTA can name.")
            .font(.custom("Satoshi-Variable", size: 12))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }

    /// Matches `PrimaryButton`'s look so the CTA reads identically to Save Settings elsewhere.
    private func primaryLabel(_ title: String, disabled: Bool = false) -> some View {
        Text(title)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(disabled ? Color.gray : Color("primaryButtonColor"))
            .cornerRadius(10)
    }

    /// The matte secondary treatment used by App Limits' "Select Apps".
    private func secondaryLabel(_ title: String, disabled: Bool = false) -> some View {
        Label(title, systemImage: "photo")
            .font(.headline)
            .foregroundColor(disabled ? .secondary : Color("primaryColor"))
            .frame(maxWidth: .infinity)
            .padding()
            .background(disabled ? Color(.systemGray5) : Color("primaryColor").opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Export rendering

    @MainActor
    private func regenerateExports(for settings: UserSettings) {
        guard settings.hasViableAppLimits else {
            pdfURL = nil
            pngURL = nil
            return
        }
        let card = LimitsReportCard(
            mode: .export,
            userName: userName,
            settings: settings,
            generatedAt: generatedAt
        )
        pdfURL = renderPDF(card)
        pngURL = renderPNG(card)
    }

    /// The exported page: fixed width, margins, and a forced light scheme so the artifact
    /// looks the same no matter the sender's appearance setting.
    @MainActor
    private func exportPage(_ card: LimitsReportCard) -> some View {
        card
            .frame(width: Self.exportCardWidth)
            .padding(Self.exportPageMargin)
            .background(Color.white)
            .environment(\.colorScheme, .light)
    }

    @MainActor
    private func renderPDF(_ card: LimitsReportCard) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PPTA-Limits.pdf")
        let renderer = ImageRenderer(content: exportPage(card))
        renderer.proposedSize = ProposedViewSize(
            width: Self.exportCardWidth + Self.exportPageMargin * 2,
            height: nil
        )

        var succeeded = false
        renderer.render { size, draw in
            var mediaBox = CGRect(origin: .zero, size: size)
            guard let consumer = CGDataConsumer(url: url as CFURL),
                  let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return }
            context.beginPDFPage(nil)
            draw(context)
            context.endPDFPage()
            context.closePDF()
            succeeded = true
        }
        return succeeded ? url : nil
    }

    @MainActor
    private func renderPNG(_ card: LimitsReportCard) -> URL? {
        let renderer = ImageRenderer(content: exportPage(card))
        renderer.proposedSize = ProposedViewSize(
            width: Self.exportCardWidth + Self.exportPageMargin * 2,
            height: nil
        )
        renderer.scale = 3

        guard let data = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PPTA-Limits.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("DEBUG: ShareLimitsView failed to write PNG: \(error)")
            return nil
        }
    }
}
