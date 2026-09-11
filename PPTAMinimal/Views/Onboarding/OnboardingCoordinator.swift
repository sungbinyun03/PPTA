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
    case profile
    case chooseApps
    case yourRules
    case findCoach
    case completed
}

final class OnboardingCoordinator: ObservableObject {
    @Published private(set) var currentStep: OnboardingStep = .intro
    @Published var onboardingComplete: Bool = false

    // MARK: - Act II draft
    //
    // Apps, limit, and pressure live here rather than being written straight to
    // `UserSettingsManager`, so backing out of a step leaves no half-applied configuration
    // behind. All three are committed together in `commitConfiguration()`.

    @Published var draftSelection = FamilyActivitySelection()
    @Published var draftThresholdHour: Int = 1
    @Published var draftThresholdMinutes: Int = 0
    @Published var draftPressureLevel: PressureLevel = .standard

    /// Direction of the last transition, so the container can slide Back the opposite way from
    /// Next. Owned here rather than in the view because every screen calls `advance()` itself.
    @Published private(set) var isGoingBack: Bool = false

    /// Whether the profile step is part of this run. Apple / Google sign-in usually supplies a
    /// display name already, and re-asking for it is a dead tap.
    private(set) var includesProfile: Bool = true

    /// Which flow this run is.
    /// - `fresh`: a first-time setup (the full flow).
    /// - `reconfigure`: a post-reinstall re-grant. Screen Time authorization does not survive an
    ///   uninstall, so the user must re-grant it and re-confirm apps + limit/pressure — but their
    ///   account (coaches, trainees, everything in Firestore) is preserved. Intro/profile/find-coach
    ///   are skipped and the config steps are pre-seeded from the existing settings.
    enum Flow { case fresh, reconfigure }
    private(set) var flow: Flow = .fresh

    private var uid: String? { Auth.auth().currentUser?.uid }
    private var stepKey: String? { uid.map { "onboardingStep_\($0)" } }

    // MARK: - Flow shape

    /// The steps this run will walk, in order. `.completed` is deliberately excluded — it is a
    /// terminal state, not a screen, so it never counts toward progress.
    var steps: [OnboardingStep] {
        switch flow {
        case .reconfigure:
            // Only the steps that a reinstall actually invalidates: re-grant Screen Time + confirm
            // apps, then re-set the limit/pressure. Coaches/trainees are untouched, so no find-coach.
            return [.chooseApps, .yourRules]
        case .fresh:
            var all: [OnboardingStep] = [.intro, .profile, .chooseApps, .yourRules, .findCoach]
            if !includesProfile { all.removeAll { $0 == .profile } }
            return all
        }
    }

    /// Zero-based position of the current step, for the page indicator.
    var progressIndex: Int {
        steps.firstIndex(of: currentStep) ?? 0
    }

    var progressTotal: Int { steps.count }

    var canGoBack: Bool {
        currentStep != .completed && progressIndex > 0
    }

    // MARK: - Configuration

    /// Called once by the container before the first render.
    ///
    /// - Parameter hasDisplayName: whether the signed-in user already has a usable name. When
    ///   true the profile step is dropped from `steps` entirely rather than being auto-skipped
    ///   at runtime, which keeps `goBack()` from landing on a screen that immediately advances
    ///   again.
    func configure(hasDisplayName: Bool, flow: Flow = .fresh, seed: UserSettings? = nil) {
        self.flow = flow
        switch flow {
        case .reconfigure:
            // Pre-fill the config from the user's existing settings and jump straight to the first
            // reconfigure step. No `restoreStep()` — a reconfigure always starts at the top.
            if let seed { seedDrafts(from: seed) }
            currentStep = .chooseApps
        case .fresh:
            includesProfile = !hasDisplayName
            restoreStep()
        }
    }

    /// Pre-fills the Act II draft from existing Firestore settings so the reconfigure flow shows the
    /// user's current apps/limit/pressure to confirm or tweak, not blank defaults. The stored
    /// `ApplicationToken`s are reused as-is; if a reinstall invalidated them they render empty in the
    /// picker and the user simply re-selects, and the cleaned-up selection is what gets saved.
    private func seedDrafts(from settings: UserSettings) {
        draftSelection = settings.applications
        draftThresholdHour = settings.thresholdHour
        draftThresholdMinutes = settings.thresholdMinutes
        draftPressureLevel = settings.pressureLevel.isTracking ? settings.pressureLevel : .standard
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

    // MARK: - Commit

    /// Writes the whole Act II draft in a single save.
    ///
    /// Deliberately *not* `UserSettingsManager.update {}`: that helper treats a nil document id as
    /// "still default" and silently falls back to `loadSettingsSyncFromDefaults()`, which is
    /// exactly a brand-new user's state — the draft would be replaced by defaults mid-onboarding.
    /// Mutating the shared settings object and calling `saveSettings` is the same pattern
    /// `PressureLevelView.saveToFirebase()` uses.
    ///
    /// `saveSettings` derives `isTracking` and resets `traineeStatus` from the pressure level, so
    /// neither is set here. It also notifies coaches of setup changes, but that path is guarded on
    /// the *previous* settings having viable limits — false for a new user — so finishing
    /// onboarding never pages anyone.
    @MainActor
    func commitConfiguration() {
        let manager = UserSettingsManager.shared
        let settings = manager.userSettings
        settings.applications = draftSelection
        settings.thresholdHour = draftThresholdHour
        settings.thresholdMinutes = draftThresholdMinutes
        settings.pressureLevel = draftPressureLevel
        // Durably record completion so a future reinstall — which wipes the per-device
        // `onboardingComplete_<uid>` UserDefaults flag — still recognizes this as a set-up account
        // and routes to the trimmed reconfigure flow rather than full onboarding.
        settings.onboardingCompleted = true

        // Mirror PressureLevelView: HomeView restarts monitoring from
        // `onReceive(userSettingsManager.$userSettings)`, but only when the persisted flag and the
        // actually-running activities disagree. Clearing both guarantees a clean first start.
        UserDefaults.standard.set(false, forKey: "isMonitoringActive")
        DeviceActivityManager.shared.stopMonitoring()

        manager.saveSettings(settings)
    }

    /// Whether the draft would produce a monitorable configuration. Mirrors the guard
    /// `PressureLevelView` applies before allowing a non-Off level to be saved.
    var draftHasViableLimits: Bool {
        UserSettings.appLimitsAreViable(
            thresholdHour: draftThresholdHour,
            thresholdMinutes: draftThresholdMinutes,
            applications: draftSelection
        )
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
