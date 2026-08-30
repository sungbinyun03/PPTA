//
//  IntroKeyView.swift
//  PPTAMinimal
//
//  Screen 1 of 5 — the whole product in one picture.
//
//  This replaced a three-screen concept carousel. Explaining coach / trainee / pressure levels /
//  lock-out as abstract slides, before the user has done anything, is the least persuasive place
//  to put that information. Everything else moved to the screen where it changes a decision:
//  the lock-out consequence is now explained on `YourRulesView`, next to the choice it affects.
//

import SwiftUI

struct IntroKeyView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            illustration: "onb-the-key",
            illustrationHeight: 270,
            title: "You set the limit.\nA friend holds the key.",
            message: "Screen Time lets you tap \"ignore limit\" whenever you feel like it. PPTA hands that decision to someone you trust instead.",
            primaryTitle: "Get Started",
            onPrimary: { coordinator.advance() }
        )
    }
}

#Preview {
    IntroKeyView(coordinator: OnboardingCoordinator())
}
