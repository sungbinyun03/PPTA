//
//  LaunchGate.swift
//  PPTAMinimal
//

import SwiftUI
import FirebaseAuth

/// Process-lifetime "initial load complete" signal behind the cold-launch facade (`LaunchFacadeView`).
///
/// The facade is armed once, at process start, and only when a user is already signed in: that is the
/// one path where Home pops in data and avatars as they arrive. Once dismissed it never returns —
/// the singleton outlives scenePhase changes, so background → active and re-opening a suspended app
/// leave it alone; only a fresh process starts armed again.
///
/// It is held until Home reports its first data (or `cap` passes, so offline or a failed fetch can't
/// strand the user behind it), but never for less than `minDisplay`, to avoid a one-frame flash.
@MainActor
final class LaunchGate: ObservableObject {
    static let shared = LaunchGate(initiallyVisible: Auth.auth().currentUser != nil)

    @Published private(set) var isVisible: Bool
    /// Home has loaded `userSettings` (plus the pending extension status and own avatar).
    @Published private(set) var settingsLoaded = false
    /// The coach/trainee lists are loaded and their avatars warmed.
    @Published private(set) var peopleLoaded = false

    private let minDisplay: TimeInterval
    private let cap: TimeInterval

    init(initiallyVisible: Bool, minDisplay: TimeInterval = 0.3, cap: TimeInterval = 2.5) {
        self.isVisible = initiallyVisible
        self.minDisplay = minDisplay
        self.cap = cap
    }

    func markSettingsLoaded() { settingsLoaded = true }
    func markPeopleLoaded() { peopleLoaded = true }

    /// Whether the facade may go. Ready waits out `minDisplay`; the cap overrides readiness.
    nonisolated static func shouldDismiss(elapsed: TimeInterval, isReady: Bool,
                                          minDisplay: TimeInterval, cap: TimeInterval) -> Bool {
        elapsed >= cap || (isReady && elapsed >= minDisplay)
    }

    /// Polls until the facade may go, then hides it. Cheap (50ms, at most `cap` seconds) and avoids
    /// stitching four publishers plus two timers together.
    func run(isReady: @MainActor () -> Bool) async {
        let start = Date()
        while isVisible {
            let elapsed = Date().timeIntervalSince(start)
            if Self.shouldDismiss(elapsed: elapsed, isReady: isReady(), minDisplay: minDisplay, cap: cap) {
                isVisible = false
                return
            }
            try? await Task.sleep(nanoseconds: 50_000_000)
            if Task.isCancelled { return }
        }
    }

    /// Returns once the facade is gone (immediately if it never showed). Used to hold a popover back
    /// until it would be visible rather than presented underneath the overlay.
    func waitUntilDismissed() async {
        guard isVisible else { return }
        for await visible in $isVisible.values where !visible { return }
    }
}
