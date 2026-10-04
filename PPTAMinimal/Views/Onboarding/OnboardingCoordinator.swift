//
//  OnboardingCoordinator.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 3/2/25.
//

import SwiftUI
import FamilyControls
import FirebaseAuth

/// One screen of the onboarding flow.
///
/// The *order* lives in `OnboardingCoordinator.steps`, not in a hand-written `advance()` switch.
/// Adding, removing, or reordering a screen is a one-line change there, and `PageIndicator`
/// derives its position from the same array, so the dots can never drift out of sync with the
/// flow the way they did when each view hardcoded its own `page:` index.
enum OnboardingStep: String, CaseIterable {
    case intro
    case howItWorks
    case profile
    case appLimits
    case findCoach
    case completed
}

final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .intro
    @Published var onboardingComplete: Bool = false

    // The app-limits step (apps + limit + pressure) is now handled by the shared `AppLimitsView`,
    // which reads/writes `UserSettingsManager` directly and saves via its own `saveToFirebase`
    // (coach notifications, ring reset, commitment streak, onboardingCompleted flag). The
    // coordinator no longer holds Act II drafts or commits them.

    /// Direction of the last transition, so the container can slide Back the opposite way from
    /// Next. Owned here rather than in the view because every screen calls `advance()` itself.
    @Published private(set) var isGoingBack: Bool = false

    private var uid: String? { Auth.auth().currentUser?.uid }
    private var stepKey: String? { uid.map { "onboardingStep_\($0)" } }

    // MARK: - Flow shape

    /// The steps this run will walk, in order. `.completed` is deliberately excluded — it is a
    /// terminal state, not a screen, so it never counts toward progress.
    /// One flow for everyone — new accounts, reinstalls and new phones alike. Returning users see
    /// their saved App Limits pre-filled. The profile step always shows (pre-filled when the name is
    /// known): it also sets the profile picture, which Apple/Google sign-in never supplies.
    let steps: [OnboardingStep] = [.intro, .howItWorks, .profile, .appLimits, .findCoach]

    /// Zero-based position of the current step, for the page indicator.
    var progressIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var progressTotal: Int { steps.count }

    var canGoBack: Bool {
        currentStep != .completed && progressIndex > 0
    }

    // MARK: - Configuration

    /// Called once by the container before the first render: restores an abandoned run.
    func configure() {
        restoreStep()
    }

    // MARK: - Navigation

    func advance() {
        guard let index = steps.firstIndex(of: currentStep) else { return }
        isGoingBack = false
        let next = index + 1
        if next < steps.count {
            setStep(steps[next])
        } else {
            setStep(.completed)
            completeOnboarding()
        }
    }

    func goBack() {
        guard let index = steps.firstIndex(of: currentStep), index > 0 else { return }
        isGoingBack = true
        setStep(steps[index - 1])
    }

    private func setStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.28)) {
            currentStep = step
        }
        persistStep(step)
    }

    // MARK: - Resume

    /// Restores an abandoned run to the step it was left on.
    ///
    /// Only the *step* is persisted, never completion: the per-uid `onboardingComplete_<uid>` flag
    /// is still written exclusively at the end of `findCoach`, so a user who quits partway is
    /// resumed rather than dropped into a half-configured app.
    private func restoreStep() {
        guard let key = stepKey,
              let raw = UserDefaults.standard.string(forKey: key),
              let saved = OnboardingStep(rawValue: raw),
              steps.contains(saved)
        else { return }
        currentStep = saved
    }

    private func persistStep(_ step: OnboardingStep) {
        guard let key = stepKey else { return }
        if step == .completed {
            UserDefaults.standard.removeObject(forKey: key)
        } else {
            UserDefaults.standard.set(step.rawValue, forKey: key)
        }
    }

    /// Only ever called from the end of `.findCoach`. There is deliberately no way to reach this
    /// early: an abandoned run leaves the per-uid flag unset, so the next launch resumes
    /// onboarding rather than dropping the user into a half-configured app.
    private func completeOnboarding() {
        onboardingComplete = true
    }
}
