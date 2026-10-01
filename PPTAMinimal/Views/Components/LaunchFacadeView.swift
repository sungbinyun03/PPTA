//
//  LaunchFacadeView.swift
//  PPTAMinimal
//

import SwiftUI

/// Cold-launch cover. Sits over the real root (so Home loads underneath) until `LaunchGate` says the
/// initial data is in, then fades out. The system launch screen is the generated blank one
/// (`UILaunchScreen_Generation`), i.e. `systemBackground`, so this matches it and the icon appears
/// on the same background in light and dark.
struct LaunchFacadeView: View {
    @ObservedObject private var gate = LaunchGate.shared
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false
    @State private var showSpinner = false

    private let iconSize: CGFloat = 120

    /// Signed out: nothing to wait for. Signed in: the profile must resolve first; if that lands on
    /// onboarding (not Home) there is no Home data to wait for, so dismiss right away rather than
    /// hold the user behind a splash for data they won't see.
    private var isReady: Bool {
        guard viewModel.userSession != nil else { return true }
        guard viewModel.currentUser != nil else { return false }
        if !viewModel.isOnboardingComplete || viewModel.needsScreenTimeReconfigure { return true }
        return gate.settingsLoaded && gate.peopleLoaded
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 24) {
                Image("launch_logo")
                    .resizable()
                    .frame(width: iconSize, height: iconSize)
                    .clipShape(RoundedRectangle(cornerRadius: iconSize * 0.2237, style: .continuous))
                    .scaleEffect(pulsing ? 1.04 : 1.0)
                if showSpinner {
                    ProgressView().transition(.opacity)
                }
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulsing = true }
        }
        .task {
            // Only if the load is genuinely slow.
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            withAnimation(.easeIn(duration: 0.2)) { showSpinner = true }
        }
        .task { await gate.run(isReady: { isReady }) }
    }
}
