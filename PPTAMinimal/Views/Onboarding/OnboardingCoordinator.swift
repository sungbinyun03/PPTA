//
//  OnboardingCoordinator.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI

enum OnboardingStep {
    case welcome
    case createProfile
    case enableTracking
    case enableNotifications
    case findFriends
    case completed
}

class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .welcome
    @Published var onboardingComplete: Bool = false

    func advance() {
        switch currentStep {
        case .welcome:
            currentStep = .createProfile
        case .createProfile:
            currentStep = .enableTracking
        case .enableTracking:
            currentStep = .enableNotifications
        case .enableNotifications:
            currentStep = .findFriends
        case .findFriends:
            currentStep = .completed
            completeOnboarding()
        case .completed:
            break
        }
    }

    func goBack() {
        switch currentStep {
        case .welcome:
            break
        case .createProfile:
            currentStep = .welcome
        case .enableTracking:
            currentStep = .createProfile
        case .enableNotifications:
            currentStep = .enableTracking
        case .findFriends:
            currentStep = .enableNotifications
        case .completed:
            break
        }
    }

    private func completeOnboarding() {
        onboardingComplete = true
    }

    func skipToMainApp() {
        completeOnboarding()
    }
}
