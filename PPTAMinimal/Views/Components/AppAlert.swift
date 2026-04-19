import SwiftUI

struct AppAlert: View {
    let title: String
    let message: String
    let buttonTitle: String
    let onDismiss: () -> Void

    private let primaryColor = Color("primaryColor")

    var body: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(title)
                        .font(.custom("BambiBold", size: 22))
                        .foregroundColor(primaryColor)
                        .multilineTextAlignment(.center)

                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    onDismiss()
                } label: {
                    Text(buttonTitle)
                        .font(.headline)
                        .foregroundColor(primaryColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(primaryColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
            .padding(24)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 24, y: 8)
            .padding(.horizontal, 40)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

extension View {
    func appAlert(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        buttonTitle: String = "Got it",
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        self.overlay {
            if isPresented.wrappedValue {
                AppAlert(title: title, message: message, buttonTitle: buttonTitle) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented.wrappedValue = false
                    }
                    onDismiss?()
                }
                .zIndex(999)
            }
        }
        .animation(.easeOut(duration: 0.2), value: isPresented.wrappedValue)
    }
}
