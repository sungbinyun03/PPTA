import SwiftUI

struct CreateProfileView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var displayName: String = ""

    private var initials: String {
        let parts = displayName.trimmingCharacters(in: .whitespaces).split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        } else if let first = parts.first, !first.isEmpty {
            return String(first.prefix(2))
        }
        return ""
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 6) {
                Text("Create Profile")
                    .font(.custom("BambiBold", size: 32))
                    .foregroundColor(Color("primaryColor"))
                Text("How should your friends know you?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)

            // Avatar
            ZStack {
                Circle()
                    .fill(Color("primaryColor").opacity(0.12))
                    .frame(width: 120, height: 120)

                if initials.isEmpty {
                    Image(systemName: "person.fill")
                        .resizable()
                        .scaledToFit()
                        .foregroundColor(Color("primaryColor").opacity(0.4))
                        .frame(width: 48, height: 48)
                } else {
                    Text(initials.uppercased())
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundColor(Color("primaryColor"))
                }
            }
            .padding(.vertical, 32)

            InputView(
                text: $displayName,
                title: "Display Name",
                placeholder: "Your name"
            )
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 16) {
                PrimaryButton(
                    title: "Next",
                    isDisabled: displayName.trimmingCharacters(in: .whitespaces).isEmpty
                ) {
                    Task {
                        await viewModel.updateUserDisplayName(
                            displayName: displayName.trimmingCharacters(in: .whitespaces)
                        )
                        coordinator.advance()
                    }
                }
                .padding(.horizontal, 24)

                PageIndicator(page: 1, length: 5)
                    .padding(.bottom, 36)
            }
        }
        .onAppear {
            if let name = viewModel.currentUser?.name, !name.isEmpty, name != "Unknown" {
                displayName = name
            }
        }
        .onChange(of: viewModel.currentUser) { _, user in
            guard displayName.isEmpty else { return }
            if let name = user?.name, !name.isEmpty, name != "Unknown" {
                displayName = name
            }
        }
    }
}

#Preview {
    CreateProfileView(coordinator: OnboardingCoordinator())
}
