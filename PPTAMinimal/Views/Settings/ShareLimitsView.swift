//
//  ShareLimitsView.swift
//  PPTAMinimal
//
//  Lets a trainee hand their coaches a readable summary of the rules they're playing by.
//
//  Screenshot-only by design. Monitored apps are drawn by `Label(token)`, which the system
//  renders out of process — `ImageRenderer` cannot capture it (verified: it draws a
//  placeholder row, not the app). A real screenshot can, so that is the whole share flow.
//  Coaches also see these stats natively on the profile sheet.
//

import SwiftUI
import UIKit
import FamilyControls
import ManagedSettings

// MARK: - Report card

struct LimitsReportCard: View {
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
    /// DeviceActivity can't provide, since it only reports usage.
    private let resistedApps: [MonitoredAppStat]

    init(userName: String, settings: UserSettings, generatedAt: Date = Date()) {
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

        var resisted: [MonitoredAppStat] = []
        for token in settings.applications.applicationTokens {
            guard let name = AppNameStore.name(for: token) else { continue }
            let blocks = AppNameStore.blocks(for: token)
            guard blocks > 0 else { continue }
            resisted.append(MonitoredAppStat(name: name, blocks30d: blocks))
        }
        self.resistedApps = Array(
            resisted.sorted { $0.blocks30d > $1.blocks30d }.prefix(3)
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
            InitialsProfilePicView(
                name: userName,
                profilePicUrl: profileImageURL?.absoluteString,
                size: 44
            )
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

    enum MonitoredItem: Hashable {
        case app(ApplicationToken)
        case category(ActivityCategoryToken)
    }

    private var monitoringBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            kicker(monitoredItems.isEmpty ? "Monitoring" : "Monitoring (\(monitoredItems.count))")
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
            kicker("Most resisted (30 days)")
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
                        Text("\(resistedApps[index].blocks30d) blocks")
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

    // MARK: Shared bits

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

    /// Stamped once per visit so the card's date is stable while it's on screen.
    @State private var generatedAt = Date()

    private var userName: String { viewModel.currentUser?.name ?? "PPTA User" }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Share My Limits")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Divider()

                LimitsReportCard(
                    userName: userName,
                    settings: settingsMgr.userSettings,
                    generatedAt: generatedAt
                )

                screenshotTip

                Text("Your coaches can also see these on your profile.")
                    .font(.custom("Satoshi-Variable", size: 12))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification)) { _ in
            NotificationManager.shared.showInAppMessage(
                title: "Screenshot saved",
                body: "Send it to your coaches so they know your rules."
            )
        }
    }

    private var screenshotTip: some View {
        HStack(spacing: 10) {
            Image(systemName: "camera.viewfinder")
                .foregroundColor(Color("primaryColor"))
            Text("Screenshot this page to share your limits — app names only appear in screenshots.")
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
}
