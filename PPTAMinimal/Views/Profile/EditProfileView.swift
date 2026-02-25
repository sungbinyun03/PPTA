import SwiftUI

struct EditProfileView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName: String = ""
    @State private var isSaving = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Text("Edit Profile")
                .font(.largeTitle)
                .fontWeight(.medium)
                .foregroundStyle(Color("primaryColor"))
            
            InputView(
                text: $displayName,
                title: "Display Name",
                placeholder: "John Doe"
            )
            .borderedContainer()
            
            Spacer()
            
            PrimaryButton(title: isSaving ? "Saving..." : "Save", isDisabled: displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving) {
                Task {
                    isSaving = true
                    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    await viewModel.updateUserDisplayName(displayName: trimmed)
                    isSaving = false
                    dismiss()
                }
            }
        }
        .padding()
        .onAppear {
            displayName = viewModel.currentUser?.name ?? ""
        }
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}

