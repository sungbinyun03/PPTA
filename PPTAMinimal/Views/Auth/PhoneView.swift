import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID = ""
    @State private var isCodeSent = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    @FocusState private var isPhoneFocused: Bool
    @FocusState private var isCodeFocused: Bool

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel

    private let primaryColor = Color("primaryColor")

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 4)

            ScrollView {
                if !isCodeSent {
                    phoneEntryView
                } else {
                    codeEntryView
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Phone Entry

    var phoneEntryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Verify your number")
                    .font(.custom("BambiBold", size: 28))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(.center)
                Text("We'll send a one-time code\nto confirm it's you.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 24)

            Image("onboarding-illustration-verify")
                .resizable()
                .scaledToFit()
                .invertedForDarkMode()
                .frame(maxHeight: 180)
                .padding(.horizontal, 56)

            VStack(alignment: .leading, spacing: 8) {
                Text("Phone Number")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(primaryColor.opacity(0.6))
                    .textCase(.uppercase)

                HStack(spacing: 10) {
                    Text("+1")
                        .font(.body)
                        .foregroundColor(primaryColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(primaryColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    TextField("(555) 867-5309", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                        .focused($isPhoneFocused)
                        .font(.body)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                        .background(primaryColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
            .padding(.horizontal, 24)

            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
            }

            PrimaryButton(
                title: isLoading ? "Sending..." : "Send Code",
                isDisabled: phoneNumber.isEmpty || isLoading
            ) {
                isPhoneFocused = false
                Task { await sendVerificationCode() }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPhoneFocused = true
            }
        }
    }

    // MARK: - Code Entry

    var codeEntryView: some View {
        VStack(spacing: 24) {
            VStack(spacing: 6) {
                Text("Enter the code")
                    .font(.custom("BambiBold", size: 28))
                    .foregroundColor(primaryColor)
                    .multilineTextAlignment(.center)
                Text("Sent to \(formattedPhoneNumber)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)

            // Hidden real input — drives the digit boxes below
            TextField("", text: $verificationCode)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isCodeFocused)
                .opacity(0)
                .frame(height: 0)
                .onChange(of: verificationCode) { _, newValue in
                    if newValue.count > 6 { verificationCode = String(newValue.prefix(6)) }
                    if newValue.count == 6 { Task { await verifyCode() } }
                }

            // OTP digit boxes
            HStack(spacing: 10) {
                ForEach(0..<6, id: \.self) { index in
                    VerificationDigitField(index: index, code: $verificationCode)
                }
            }
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { isCodeFocused = true }

            if let msg = errorMessage {
                Text(msg)
                    .font(.caption)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
            }

            PrimaryButton(title: "Verify", isDisabled: verificationCode.count != 6) {
                Task { await verifyCode() }
            }
            .padding(.horizontal, 24)

            Button {
                Task { verificationCode = ""; await sendVerificationCode() }
            } label: {
                Text("Resend code")
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
            }
            .padding(.bottom, 40)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isCodeFocused = true
            }
        }
    }

    // MARK: - Helpers

    var formattedPhoneNumber: String {
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard cleaned.count >= 10 else { return phoneNumber }
        return "(\(cleaned.prefix(3))) \(cleaned.dropFirst(3).prefix(3))-\(cleaned.dropFirst(6).prefix(4))"
    }

    private func sendVerificationCode() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard !cleaned.isEmpty else {
            errorMessage = "Please enter a valid phone number."
            return
        }

        do {
            if try await authViewModel.isPhoneNumberTaken(phoneNumber, excludingUid: authViewModel.userSession?.uid) {
                errorMessage = "This phone number is already registered to another account."
                return
            }
        } catch {
            errorMessage = AuthViewModel.userFacingMessage(for: error)
            return
        }

        let e164 = cleaned.hasPrefix("1") ? "+\(cleaned)" : "+1\(cleaned)"

        PhoneAuthProvider.provider().verifyPhoneNumber(e164, uiDelegate: nil) { id, error in
            DispatchQueue.main.async {
                if let error {
                    self.errorMessage = AuthViewModel.userFacingMessage(for: error)
                    return
                }
                guard let id else {
                    self.errorMessage = "Unable to send code. Please try again."
                    return
                }
                self.verificationID = id
                self.isCodeSent = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.isCodeFocused = true
                }
            }
        }
    }

    private func verifyCode() async {
        errorMessage = nil
        guard verificationCode.count == 6, !verificationID.isEmpty else { return }

        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )

        guard let currentUser = Auth.auth().currentUser else { return }
        do {
            _ = try await currentUser.link(with: credential)
            await authViewModel.updateUserPhoneNumber(phoneNumber: phoneNumber)
            dismiss()
        } catch {
            errorMessage = AuthViewModel.userFacingMessage(for: error)
        }
    }
}

// MARK: - OTP digit box

struct VerificationDigitField: View {
    let index: Int
    @Binding var code: String

    private let primaryColor = Color("primaryColor")

    var digit: String? {
        guard code.count > index else { return nil }
        return String(code[code.index(code.startIndex, offsetBy: index)])
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(primaryColor.opacity(digit != nil ? 0.12 : 0.06))
                .frame(height: 56)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(digit != nil ? primaryColor.opacity(0.4) : Color.clear, lineWidth: 1.5)
                )

            if let d = digit {
                Text(d)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(primaryColor)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    PhoneVerificationView()
        .environmentObject(AuthViewModel())
}
