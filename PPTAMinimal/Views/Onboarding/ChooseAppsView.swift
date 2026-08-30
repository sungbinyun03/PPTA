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
    @Environment(\.openURL) private var openURL

    private var hasSelection: Bool {
        !coordinator.draftSelection.applicationTokens.isEmpty ||
        !coordinator.draftSelection.categoryTokens.isEmpty
    }

    private var selectionCount: Int {
        coordinator.draftSelection.applicationTokens.count +
        coordinator.draftSelection.categoryTokens.count
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            illustration: hasSelection ? nil : "onb-pick-apps",
            illustrationHeight: 230,
            title: "Which apps eat your day?",
            message: hasSelection
                ? "Your limit applies to these together, not to each one separately."
                : "PPTA counts the time you spend in the apps you pick here. It can't read your messages or see anything else you do.",
            primaryTitle: hasSelection ? "Next" : "Choose my apps",
            secondaryTitle: hasSelection ? "Change selection" : nil,
            onSecondary: hasSelection ? beginSelection : nil,
            onPrimary: primaryAction
        ) {
            VStack(spacing: 16) {
                if hasSelection {
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
        if hasSelection {
            coordinator.advance()
        } else {
            beginSelection()
        }
    }

    /// Requests authorization if needed, then opens the picker in the same tap.
    ///
    /// The picker cannot be presented before authorization is approved, so these must be
    /// sequential — but there is no reason for the user to experience them as two steps.
    private func beginSelection() {
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
                authorizationDenied = !approved
                if approved { isPickerPresented = true }
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

#Preview {
    ChooseAppsView(coordinator: OnboardingCoordinator())
}
