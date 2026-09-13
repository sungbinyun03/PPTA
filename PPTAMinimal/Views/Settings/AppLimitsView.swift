//
//  AppLimitsView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 4/5/25.
//
//  Combined "App Limits" screen: time limit + monitored apps + pressure level, saved together.
//  The standalone `PressureLevelView` (and its Settings row) is intentionally left in place; this
//  screen duplicates the pressure selection in a compact horizontal form for convenience.
//

import SwiftUI
import FamilyControls

struct AppLimitsView: View {
    @ObservedObject var userSettingsManager = UserSettingsManager.shared

    @State private var isPickerPresented = false
    @State private var showTimeLimitSheet = false
    @State private var showFullAppList = false
    @State private var showSavedAlert = false
    /// "Are you sure?" confirmation shown before a save actually applies.
    @State private var showSaveConfirm = false
    /// Shown when a non-Off pressure level is chosen without viable limits (time + at least one app).
    @State private var showViableRequiredAlert = false

    /// A Hardcore trainee who is cut off can't edit limits (that would be an escape hatch). The
    /// explanatory banner was removed per design, but the guard stays — controls are disabled.
    private var isLocked: Bool {
        userSettingsManager.userSettings.traineeStatus == .cutOff &&
        userSettingsManager.userSettings.pressureLevel == .hardcore
    }

    @State private var selection = FamilyActivitySelection()
    /// Drafts (saved only on "Save Settings"), like `selection`.
    @State private var draftThresholdHour: Int = 0
    @State private var draftThresholdMinutes: Int = 0
    @State private var draftPressureLevel: PressureLevel = .off

    /// Inline "?" expansions.
    @State private var showTimeLimitInfo = false
    @State private var showPressureInfo = false

    /// When the current App Limits took effect — backed by `startDailyStreakDate` (the Commitment
    /// Streak start), which `saveToFirebase` resets whenever the apps or limit change. `—` if unset.
    private var lastChangedText: String {
        guard let date = userSettingsManager.userSettings.startDailyStreakDate else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("App Limits")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            datesBlock

            timeLimitSection
            monitoredAppsSection
            pressureSection

            PrimaryButton(
                title: hasUnsavedChanges ? "Save Settings" : "Save Settings (Unchanged)",
                isDisabled: isLocked || !hasUnsavedChanges,
                disabledBackground: Color(.systemGray4)
            ) {
                showSaveConfirm = true
            }

            Spacer()
        }
        .padding()
        .familyActivityPicker(isPresented: $isPickerPresented, selection: $selection)
        .sheet(isPresented: $showTimeLimitSheet) {
            TimeLimitSheetView(draftHours: $draftThresholdHour, draftMinutes: $draftThresholdMinutes)
        }
        .sheet(isPresented: $showFullAppList) {
            MonitoredAppsListView(
                selection: selection,
                todayText: currentDateText,
                lastChangedText: lastChangedText
            )
        }
        .appConfirm(
            isPresented: $showSaveConfirm,
            title: "Are you sure?",
            message: "Any change that isn't decreasing your time limit or going from Standard to Hardcore will reset your Commitment Streak.",
            confirmTitle: "Yes",
            cancelTitle: "No"
        ) {
            if saveToFirebase() { showSavedAlert = true }
        }
        .appAlert(
            isPresented: $showSavedAlert,
            title: "Settings Saved",
            message: "Your coaches have been notified, share a screenshot of this page and send it to them so that they know what your goals are!"
        )
        .appAlert(
            isPresented: $showViableRequiredAlert,
            title: "Set up App Limits first",
            message: "Set a daily time limit and pick at least one app before choosing Standard or Hardcore."
        )
        .onAppear {
            loadFromUserSettings()
        }
    }

    // MARK: - Dates

    private var datesBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Today: \(currentDateText)")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
            Text("Last changed: \(lastChangedText)")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Time limit

    private var timeLimitSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Time Limit")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                infoButton($showTimeLimitInfo, "About the time limit")
                Spacer()
            }

            if showTimeLimitInfo {
                infoCaption("Limit applies to total combined usage across all selected apps.")
            }

            ZStack(alignment: .topTrailing) {
                Text(timeLimitDisplayText)
                    .font(.title2)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                editButton { showTimeLimitSheet = true }
            }
            .modifier(SettingsBox())
        }
    }

    // MARK: - Monitored apps

    private var monitoredAppsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monitored Apps")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                Spacer()
            }

            ZStack(alignment: .topTrailing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(appCountText)
                        .font(.custom("Satoshi-Variable", size: 14))
                        .fontWeight(.medium)
                        .foregroundColor(selectedCount == 0 ? .secondary : .primary)

                    if selectedCount > 0 {
                        appPreviewGrid
                        HStack {
                            Spacer()
                            Button { showFullAppList = true } label: {
                                Text("tap to see full list")
                                    .font(.custom("Satoshi-Variable", size: 11))
                                    .foregroundColor(Color("primaryColor").opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                editButton { isPickerPresented = true }
            }
            .modifier(SettingsBox())
        }
    }

    /// Up to 6 apps in a 2×3 grid (app tokens first, then categories to fill any remaining slots).
    private var appPreviewGrid: some View {
        let appPreview = Array(selection.applicationTokens.prefix(6))
        let remaining = max(0, 6 - appPreview.count)
        let catPreview = Array(selection.categoryTokens.prefix(remaining))
        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            alignment: .leading,
            spacing: 10
        ) {
            ForEach(appPreview, id: \.self) { token in
                Label(token)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            ForEach(catPreview, id: \.self) { token in
                Label(token)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Pressure level

    private var pressureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("Pressure Level")
                    .font(.custom("SatoshiVariable-Bold_Light", size: 20))
                infoButton($showPressureInfo, "About pressure levels")
                Spacer()
            }

            if showPressureInfo {
                VStack(alignment: .leading, spacing: 6) {
                    pressureDescription("Off", "No monitoring or pressure. Take a break :)")
                    pressureDescription("Standard", "Coaches can lock you out when you exceed your limit.")
                    pressureDescription("Hardcore", "You get locked instantly the moment you exceed.")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                pressurePill(.off, "Off",
                             background: Color("primaryColor").opacity(0.08),
                             foreground: Color("primaryColor"))
                pressurePill(.standard, "Standard",
                             background: Color("primaryButtonColor"),
                             foreground: .white, star: true)
                pressurePill(.hardcore, "Hardcore",
                             background: Color("primaryColor"),
                             foreground: .white)
            }
            .modifier(SettingsBox())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .disabled(isLocked)
    }

    private func pressurePill(
        _ level: PressureLevel,
        _ title: String,
        background: Color,
        foreground: Color,
        star: Bool = false
    ) -> some View {
        let selected = draftPressureLevel == level
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { draftPressureLevel = level }
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.custom("Satoshi-Variable", size: 15))
                    .fontWeight(.semibold)
                    .foregroundColor(foreground)
                if star {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(selected ? 0.7 : 0), lineWidth: 3)
            )
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(foreground)
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func pressureDescription(_ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("\(title):")
                .font(.custom("Satoshi-Variable", size: 12))
                .fontWeight(.semibold)
                .foregroundColor(Color("primaryColor"))
            Text(text)
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Shared pieces

    private func infoButton(_ flag: Binding<Bool>, _ label: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { flag.wrappedValue.toggle() }
        } label: {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 15))
                .foregroundColor(Color("primaryColor").opacity(0.6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func infoCaption(_ text: String) -> some View {
        Text(text)
            .font(.custom("Satoshi-Variable", size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func editButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(isLocked ? .secondary : Color("primaryColor"))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .accessibilityLabel("Edit")
    }

    /// Whether the drafts differ from what's saved — drives the greyed-out "(Unchanged)" state so
    /// Save can't fire a no-op (and a spurious coach notification) when nothing actually changed.
    private var hasUnsavedChanges: Bool {
        let s = userSettingsManager.userSettings
        return selection.applicationTokens != s.applications.applicationTokens
            || selection.categoryTokens != s.applications.categoryTokens
            || draftThresholdHour != s.thresholdHour
            || draftThresholdMinutes != s.thresholdMinutes
            || draftPressureLevel != s.pressureLevel
    }

    private var selectedCount: Int {
        selection.applicationTokens.count + selection.categoryTokens.count
    }

    private var appCountText: String {
        switch selectedCount {
        case 0: return "No apps selected"
        case 1: return "1 app selected"
        default: return "\(selectedCount) apps selected"
        }
    }

    /// Today's date as dd/MM/yyyy, matching the "Last changed" placeholder format.
    private var currentDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: Date())
    }

    /// Label for the **draft** daily limit (matches unsaved app selection until Save).
    private var timeLimitDisplayText: String {
        let h = draftThresholdHour
        let m = draftThresholdMinutes
        if h == 0 && m == 0 { return "Not set" }
        var parts: [String] = []
        if h > 0 { parts.append("\(h)h") }
        if m > 0 { parts.append("\(m)m") }
        return parts.joined(separator: " ")
    }

    // MARK: - Load / Save

    private func loadFromUserSettings() {
        let s = userSettingsManager.userSettings
        selection = s.applications
        draftThresholdHour = s.thresholdHour
        draftThresholdMinutes = s.thresholdMinutes
        draftPressureLevel = s.pressureLevel
    }

    /// Saves time limit + monitored apps + pressure level together.
    /// - Returns: `true` if saved; `false` if validation blocked the save.
    @discardableResult
    private func saveToFirebase() -> Bool {
        guard !isLocked else { return false }

        let wouldBeViable = UserSettings.appLimitsAreViable(
            thresholdHour: draftThresholdHour,
            thresholdMinutes: draftThresholdMinutes,
            applications: selection
        )
        // Standard/Hardcore require viable limits; Off may be saved freely (e.g. to clear tracking).
        if draftPressureLevel != PressureLevel.off, !wouldBeViable {
            showViableRequiredAlert = true
            return false
        }

        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()

        var settings = userSettingsManager.userSettings

        let oldApps = settings.applications
        let appsChanged =
            oldApps.applicationTokens != selection.applicationTokens ||
            oldApps.categoryTokens != selection.categoryTokens

        let oldTotalSec = settings.thresholdHour * 3600 + settings.thresholdMinutes * 60
        let newTotalSec = draftThresholdHour * 3600 + draftThresholdMinutes * 60
        let limitIncreased = newTotalSec > oldTotalSec
        // `settings` still holds the pre-save pressure here (assigned below), so this compares old vs draft.
        // A pressure change resets the streak in EVERY case except tightening Standard → Hardcore
        // (turning on, turning off, or Hardcore → Standard all reset).
        let pressureResetsStreak =
            settings.pressureLevel != draftPressureLevel &&
            !(settings.pressureLevel == PressureLevel.standard && draftPressureLevel == PressureLevel.hardcore)

        // `startDailyStreakDate` backs the Commitment Streak (days since App Limits last changed), so
        // a change to apps, a limit increase, or a (non Standard→Hardcore) pressure change resets it —
        // as does first setup. A limit decrease and Standard→Hardcore deliberately preserve the streak.
        if appsChanged || limitIncreased || pressureResetsStreak || settings.startDailyStreakDate == nil {
            settings.startDailyStreakDate = Date()
        }

        settings.applications = selection
        settings.thresholdHour = draftThresholdHour
        settings.thresholdMinutes = draftThresholdMinutes
        settings.pressureLevel = draftPressureLevel
        // Restarting monitoring (threshold → 0) means starting status fresh while tracking.
        // `saveSettings` maps Off → noStatus, so only touch this when tracking. A cut-off Hardcore
        // user can't reach here (isLocked guard), so this never clears a coach lock.
        if settings.pressureLevel != PressureLevel.off {
            settings.traineeStatus = .allClear
        }

        userSettingsManager.saveSettings(settings)
        // Rebase the screen-time ring to now so it matches the reset threshold (today only).
        DeviceActivityManager.markRingReset()
        return true
    }
}

/// Full monitored-apps list, opened from the App Limits screen. Shows the same Today / Last changed
/// dates and the complete selection in two columns.
private struct MonitoredAppsListView: View {
    let selection: FamilyActivitySelection
    let todayText: String
    let lastChangedText: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today: \(todayText)")
                        .font(.custom("Satoshi-Variable", size: 12))
                        .foregroundColor(.secondary)
                    Text("Last changed: \(lastChangedText)")
                        .font(.custom("Satoshi-Variable", size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                        alignment: .leading,
                        spacing: 12
                    ) {
                        ForEach(Array(selection.applicationTokens), id: \.self) { token in
                            Label(token)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(selection.categoryTokens), id: \.self) { token in
                            Label(token)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Monitored Apps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        // Match the tinted interior of the Monitored Apps box (systemBackground + primary 0.06).
        .presentationBackground {
            ZStack {
                Color(.systemBackground)
                Color("primaryColor").opacity(0.06)
            }
            .ignoresSafeArea()
        }
    }
}

/// Shared box chrome for the Time Limit / Monitored Apps cards.
private struct SettingsBox: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color("primaryColor").opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color("primaryColor").opacity(0.3), lineWidth: 2)
            )
    }
}
