//
//  IntroKeyView.swift
//  PPTAMinimal
//
//  Screen 1 of the fresh flow — what the app is for, in one picture. `HowItWorksView` follows
//  with the steps.
//
//  This replaced a three-screen concept carousel. Explaining coach / trainee / pressure levels /
//  lock-out as abstract slides, before the user has done anything, is the least persuasive place
//  to put that information. Everything else moved to the screen where it changes a decision:
//  the lock-out consequence is now explained on the app-limits step, next to the choice it affects.
//

import SwiftUI

struct IntroKeyView: View {
    @ObservedObject var coordinator: OnboardingCoordinator

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            illustration: "onb-the-key",
            illustrationHeight: 270,
            title: "Better screen time habits,\nenforced by friends.",
            message: "Team up with friends as coaches and trainees. Go over your daily limit and your coaches can lock your apps - and you do the same for your trainees.",
            primaryTitle: "Get Started",
            onPrimary: { coordinator.advance() }
        )
    }
}

#Preview {
    IntroKeyView(coordinator: OnboardingCoordinator())
}
