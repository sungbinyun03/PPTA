//
//  CreateProfileView.swift
//  PPTAMinimal
//
//  Screen 2 of 5 — and often skipped entirely.
//
//  `OnboardingCoordinator.configure(hasDisplayName:)` drops this step from the flow when the user
//  already has a usable name, which is the common case for Apple and Google sign-in. The step is
//  removed from `steps` rather than auto-advanced at runtime, so `goBack()` can never land on a
//  screen that immediately bounces forward again.
//

import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var displayName: String = ""
    @State private var isSaving = false

    private var trimmedName: String {
        displayName.trimmingCharacters(in: .whitespaces)
    }

    private var initials: String {
        let parts = trimmedName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        } else if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2))
        }
        return ""
    }

    var body: some View {
        OnboardingScaffold(
            coordinator: coordinator,
            title: "What should we call you?",
            message: "This is the name your coaches and trainees will see.",
            primaryTitle: isSaving ? "Saving…" : "Next",
            primaryDisabled: trimmedName.isEmpty || isSaving,
            onPrimary: save
        ) {
            VStack(spacing: 28) {
                avatar
                InputView(
                    text: $displayName,
                    title: "Display Name",
                    placeholder: "Your name"
                )
                .padding(.horizontal, 24)
            }
        }
        .onAppear(perform: prefill)
        .onChange(of: viewModel.currentUser) { _, _ in prefill() }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color("primaryColor").opacity(0.12))
                .frame(width: 116, height: 116)

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(Color("primaryColor").opacity(0.4))
                    .frame(width: 46, height: 46)
            } else {
                Text(initials.uppercased())
                    .font(.custom("BambiBold", size: 38))
                    .foregroundColor(Color("primaryColor"))
            }
        }
    }

    private func prefill() {
        guard displayName.isEmpty else { return }
        if let name = viewModel.currentUser?.name, !name.isEmpty, name != "Unknown" {
            displayName = name
        }
    }

    private func save() {
        isSaving = true
        Task {
            await viewModel.updateUserDisplayName(displayName: trimmedName)
            await MainActor.run {
                isSaving = false
                coordinator.advance()
            }
        }
    }
}

#Preview {
    CreateProfileView(coordinator: OnboardingCoordinator())
        .environmentObject(AuthViewModel())
}
