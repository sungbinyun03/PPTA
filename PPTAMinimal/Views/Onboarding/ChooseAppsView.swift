//
//  ChooseAppsView.swift
//  PPTAMinimal
//
//  Screen 3 of 5 — Screen Time authorization and app selection, chained on one tap.
//
//  These used to be two screens: a priming screen that only requested authorization, and then
//  nothing — app selection lived in Settings and was never part of onboarding at all, which is
//  why finishing onboarding used to drop the user on a Home screen that said "Not Tracking".
//  The priming copy *is* this screen's copy, so splitting them added a tap and taught nothing.
//
//  There is deliberately no skip. Without Screen Time authorization the app cannot monitor,
//  shield, or report anything, so letting someone past here produces an account that silently
//  does nothing.
//

import SwiftUI
import UIKit
import FamilyControls

struct ChooseAppsView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var isPickerPresented = false
    @State private var authorizationDenied = false
    /// Screen Time authorization is granted per install and does NOT survive an uninstall, so on a
    /// reinstall this starts false even when a selection was restored from Firestore. Tracked in
    /// @State (refreshed on appear and after a request) so the primary action can require a re-grant
    /// before advancing — otherwise a pre-filled selection would let "Next" skip authorization.
    @State private var isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
    @Environment(\.openURL) private var openURL

    private var hasSelection: Bool {
        !coordinator.draftSelection.applicationTokens.isEmpty ||
        !coordinator.draftSelection.categoryTokens.isEmpty
    }

    /// A selection is only meaningful to show or advance on once Screen Time is authorized — the
    /// tokens can't render or be applied to a shield without it. On a reinstall `hasSelection` is
    /// true (restored from Firestore) but this is false until the user re-grants.
    private var showingSelection: Bool { hasSelection && isAuthorized }

    private var selectionCount: Int {
        coordinator.draftSelection.applicationTokens.count +
        coordinator.draftSelection.categoryTokens.count
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            illustration: showingSelection ? nil : "onb-pick-apps",
            illustrationHeight: 230,
            title: "Which apps eat your day?",
            message: showingSelection
                ? "Your limit applies to these together, not to each one separately."
                : "PPTA counts the time you spend in the apps you pick here. It can't read your messages or see anything else you do.",
            primaryTitle: !isAuthorized
                ? "Enable Screen Time"
                : (hasSelection ? "Next" : "Choose my apps"),
            secondaryTitle: showingSelection ? "Change selection" : nil,
            onSecondary: showingSelection ? openPicker : nil,
            onPrimary: primaryAction
        ) {
            VStack(spacing: 16) {
                if showingSelection {
                    selectionList
                }
                if authorizationDenied {
                    deniedNotice
                }
            }
        }
        .familyActivityPicker(
            isPresented: $isPickerPresented,
            selection: $coordinator.draftSelection
        )
        .onAppear {
            // Reflect the live authorization state — on a reinstall the initializer's value is stale
            // by the time this appears, and a returning user may have granted it elsewhere.
            isAuthorized = AuthorizationCenter.shared.authorizationStatus == .approved
        }
    }

    // MARK: - Pieces

    private var selectionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(selectionCount) selected".uppercased())
                .font(.custom("Satoshi-Variable", size: 11))
                .fontWeight(.semibold)
                .tracking(1.2)
                .foregroundColor(Color("primaryColor").opacity(0.6))
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 8)

            ForEach(Array(coordinator.draftSelection.applicationTokens), id: \.self) { token in
                HStack { Label(token); Spacer() }
                    .frame(height: 40)
                    .padding(.horizontal, 14)
            }
            ForEach(Array(coordinator.draftSelection.categoryTokens), id: \.self) { token in
                HStack { Label(token); Spacer() }
                    .frame(height: 40)
                    .padding(.horizontal, 14)
            }
        }
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color("primaryColor").opacity(0.07))
        )
        .padding(.horizontal, 24)
    }

    private var deniedNotice: some View {
        VStack(spacing: 8) {
            Text("Screen Time is required for PPTA to work.")
                .font(.custom("Satoshi-Variable", size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Open Settings") { openSettings() }
                .font(.custom("Satoshi-Variable", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(Color("primaryColor"))
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Actions

    private func primaryAction() {
        if !isAuthorized {
            // Authorization is its own step — it never auto-opens the picker. The user opens the
            // picker themselves via "Choose my apps" / "Change selection".
            requestAuthorization()
        } else if hasSelection {
            coordinator.advance()
        } else {
            openPicker()
        }
    }

    /// Requests Screen Time authorization only. It deliberately does NOT open the picker — the user
    /// opens that themselves, so the selection sheet never appears on its own (fresh install or
    /// reinstall alike).
    private func requestAuthorization() {
        Task {
            let center = AuthorizationCenter.shared
            if center.authorizationStatus != .approved {
                do {
                    try await center.requestAuthorization(for: .individual)
                } catch {
                    print("Failed to request screen time auth: \(error)")
                }
            }
            // Reflect the real authorization status rather than the fact that we asked. An earlier
            // version set this unconditionally, so a denial still advanced onboarding and left the
            // user marked complete with no authorization.
            let approved = center.authorizationStatus == .approved
            await MainActor.run {
                isAuthorized = approved
                authorizationDenied = !approved
            }
        }
    }

    /// Presents the system app picker. Only ever called from an explicit tap on "Choose my apps" /
    /// "Change selection"; authorization is already granted by the time either is shown.
    private func openPicker() {
        isPickerPresented = true
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    ChooseAppsView(coordinator: OnboardingCoordinator())
}
