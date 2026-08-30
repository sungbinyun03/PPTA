//
//  YourRulesView.swift
//  PPTAMinimal
//
//  Screen 4 of 5 — the daily limit and what happens when it's crossed.
//
//  These were two separate screens in an earlier draft. "How long is fair?" and "what happens when
//  I blow past it" are one decision, and they read better adjacent. It also puts the lock-out
//  consequence on the screen where the user is actually choosing how harsh it should be, rather
//  than three screens earlier as an abstract warning.
//
//  This is the densest screen in the flow. If it ever feels cramped, splitting it back into two is
//  a one-line change to `OnboardingCoordinator.steps` — not a rewrite.
//

import SwiftUI
import UIKit

struct YourRulesView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @State private var showTimeLimitSheet = false

    /// Common daily limits, in minutes. "Custom" opens the same wheel picker Settings uses.
    private let presets: [Int] = [30, 60, 90, 120]

    private var totalMinutes: Int {
        coordinator.draftThresholdHour * 60 + coordinator.draftThresholdMinutes
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            title: "Set your rules",
            message: "You can change these later — but your coaches get told when you do.",
            primaryTitle: "Save & continue",
            primaryDisabled: !coordinator.draftHasViableLimits,
            onPrimary: commit
        ) {
            VStack(spacing: 28) {
                limitSection
                pressureSection
            }
        }
        .sheet(isPresented: $showTimeLimitSheet) {
            TimeLimitSheetView(
                draftHours: $coordinator.draftThresholdHour,
                draftMinutes: $coordinator.draftThresholdMinutes
            )
        }
    }

    // MARK: - Daily limit

    private var limitSection: some View {
        VStack(spacing: 14) {
            kicker("Daily limit")

            Text(limitText)
                .font(.custom("BambiBold", size: 40))
                .foregroundColor(Color("primaryColor"))

            HStack(spacing: 8) {
                ForEach(presets, id: \.self) { minutes in
                    presetChip(minutes)
                }
                customChip
            }
            .padding(.horizontal, 24)
        }
    }

    private var limitText: String {
        guard totalMinutes > 0 else { return "Not set" }
        var parts: [String] = []
        if coordinator.draftThresholdHour > 0 { parts.append("\(coordinator.draftThresholdHour)h") }
        if coordinator.draftThresholdMinutes > 0 { parts.append("\(coordinator.draftThresholdMinutes)m") }
        return parts.joined(separator: " ")
    }

    private func presetChip(_ minutes: Int) -> some View {
        let isSelected = totalMinutes == minutes
        return Button {
            coordinator.draftThresholdHour = minutes / 60
            coordinator.draftThresholdMinutes = minutes % 60
        } label: {
            Text(label(for: minutes))
                .font(.custom("Satoshi-Variable", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(isSelected ? .white : Color("primaryColor"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? Color("primaryColor") : Color("primaryColor").opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    private var customChip: some View {
        let isCustom = totalMinutes > 0 && !presets.contains(totalMinutes)
        return Button {
            showTimeLimitSheet = true
        } label: {
            Text("Custom")
                .font(.custom("Satoshi-Variable", size: 14))
                .fontWeight(.semibold)
                .foregroundColor(isCustom ? .white : Color("primaryColor"))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isCustom ? Color("primaryColor") : Color("primaryColor").opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }

    private func label(for minutes: Int) -> String {
        minutes < 60
            ? "\(minutes)m"
            : (minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h\(minutes % 60)")
    }

    // MARK: - Pressure level

    private var pressureSection: some View {
        VStack(spacing: 14) {
            lockMark
            kicker("When I go over my limit")

            VStack(spacing: 12) {
                PressureLevelCard(
                    level: .standard,
                    title: "Standard",
                    description: "My coaches get told, and they decide whether to lock me out.",
                    backgroundColor: Color("primaryButtonColor"),
                    textColor: .white,
                    showStar: true,
                    selection: $coordinator.draftPressureLevel
                )
                PressureLevelCard(
                    level: .hardcore,
                    title: "Hardcore",
                    description: "Lock me out the moment I hit the limit. Only a coach can let me back in.",
                    backgroundColor: Color("primaryColor"),
                    textColor: .white,
                    selection: $coordinator.draftPressureLevel
                )
            }
            .padding(.horizontal, 24)

            Text("Off is available later in Settings. Starting there would mean nothing is tracked at all.")
                .font(.custom("Satoshi-Variable", size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    /// `onb-the-loop` is still pending a redo — the generated version drifted into a "secure
    /// device sync" concept, and a checkmark-in-a-shield reads as *approved*, the opposite of
    /// *locked out*. Falls back to an SF Symbol so this screen is never missing its art.
    private var lockMark: some View {
        Group {
            if UIImage(named: "onb-the-loop") != nil {
                Image("onb-the-loop")
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "lock.iphone")
                    .resizable()
                    .scaledToFit()
            }
        }
        .foregroundStyle(Color("primaryColor"))
        .frame(height: 84)
    }

    private func kicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.custom("Satoshi-Variable", size: 11))
            .fontWeight(.semibold)
            .tracking(1.2)
            .foregroundColor(Color("primaryColor").opacity(0.6))
    }

    // MARK: - Commit

    private func commit() {
        Task { @MainActor in
            coordinator.commitConfiguration()
            coordinator.advance()
        }
    }
}

#Preview {
    YourRulesView(coordinator: OnboardingCoordinator())
}
