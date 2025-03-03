//
//  PhoneView.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 2/5/25.
//

import SwiftUI
import FirebaseAuth

struct PhoneVerificationView: View {
    @State private var phoneNumber: String = ""
    @State private var verificationCode: String = ""
    @State private var verificationID = ""
    @State private var isCodeSent = false
    @State private var errorMessage: String?
    @State private var showKeyboard = false
    @FocusState private var isTextFieldFocused: Bool
    
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    private let primaryColor = Color("primaryColor")
    private let backgroundColor = Color(UIColor.systemBackground)
    private let textFieldBackground = Color("backgroundGray")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !isCodeSent {
                // Phone number entry screen
                phoneEntryView
            } else {
                // Verification code entry screen
                codeEntryView
            }
        }
        .padding(.horizontal, 16)
        .background(backgroundColor)
        .onAppear {
            // Automatically focus the input field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    // MARK: - Phone Entry View
    var phoneEntryView: some View {
        VStack(alignment: .center, spacing: 20) {
            Text("Phone Verification")
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(primaryColor)
                .padding(.top, 20)
            
            Text("Enter your phone number to verify your account")
                .font(.subheadline)
                .foregroundColor(primaryColor)
                .padding(.bottom, 10)
            
            Image("onboarding-illustration-verify")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
            
            InputView(text: $phoneNumber, title: "Phone Number", placeholder: "(123) 456-789")
                .borderedContainer()
            
            // Error message if any
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // Send Code Button
            Button(action: {
                Task {
                    await sendVerificationCode()
                }
            }) {
                Text("Send Code")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(!phoneNumber.isEmpty ? primaryColor : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(phoneNumber.isEmpty)
            .padding(.bottom, 20)
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index == 1 ? primaryColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Code Entry View
    var codeEntryView: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            Text("Verification Code")
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(primaryColor)
                .padding(.top, 20)
            
            // Subtitle
            Text("Please enter the verification code sent to \(formattedPhoneNumber)")
                .font(.subheadline)
                .foregroundColor(primaryColor)
                .padding(.bottom, 20)
            
            // Hidden actual input field
            TextField("", text: $verificationCode)
                .keyboardType(.numberPad)
                .focused($isTextFieldFocused)
                .opacity(0)
                .frame(height: 0)
                .onChange(of: verificationCode) { _, newValue in
                    // Limit to 6 digits
                    if newValue.count > 6 {
                        verificationCode = String(newValue.prefix(5))
                    }
                    
                    // Auto-verify when code is complete
                    if newValue.count == 6 {
                        Task {
                            await verifyCode()
                        }
                    }
                }
            
            // Verification code display fields
            HStack(spacing: 8) {
                ForEach(0..<6, id: \.self) { index in
                    VerificationDigitField(index: index, code: $verificationCode)
                        .onTapGesture {
                            isTextFieldFocused = true
                        }
                }
            }
            .padding(.vertical, 20)
            
            // Error message if any
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 4)
            }
            
            Spacer()
            
            // Verify Button
            Button(action: {
                Task {
                    await verifyCode()
                }
            }) {
                Text("Verify")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(verificationCode.count == 6 ? primaryColor : Color.gray)
                    .cornerRadius(10)
            }
            .disabled(verificationCode.count != 6)
            .padding(.bottom, 20)
            
            // Resend code button
            Button(action: {
                Task {
                    verificationCode = ""
                    await sendVerificationCode()
                }
            }) {
                Text("Resend code")
                    .font(.subheadline)
                    .foregroundColor(primaryColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            
            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    Circle()
                        .fill(index == 1 ? primaryColor : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
        }
    }
    
    // Format phone number for display
    var formattedPhoneNumber: String {
        if phoneNumber.isEmpty {
            return "(XXX) XXX-XXXX"
        }
        
        // Basic formatting - in a real app, you'd want more robust formatting
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if cleaned.count >= 10 {
            let areaCode = cleaned.prefix(3)
            let prefix = cleaned.dropFirst(3).prefix(3)
            let suffix = cleaned.dropFirst(6).prefix(4)
            return "(\(areaCode)) \(prefix)-\(suffix)"
        }
        return phoneNumber
    }
    
    // Send verification code
    private func sendVerificationCode() async {
        // Clear any previous errors
        errorMessage = nil
        
        // Clean up the phone number to ensure it only contains digits
        let cleaned = phoneNumber.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        guard !cleaned.isEmpty else {
            errorMessage = "Please enter a valid phone number"
            return
        }
        
        let numberWithCountry = cleaned.hasPrefix("1") ? "+\(cleaned)" : "+1\(cleaned)"
        
        // Show loading state here if needed
        
        PhoneAuthProvider.provider().verifyPhoneNumber(numberWithCountry, uiDelegate: nil) { (verificationID, error) in
            if let error = error {
                print("Error details: \(error.localizedDescription)")
                self.errorMessage = error.localizedDescription
                return
            }
            
            guard let verificationID = verificationID else {
                print("Failed to get verification ID")
                self.errorMessage = "Failed to send verification code"
                return
            }
            
            // Success
            self.verificationID = verificationID
            self.isCodeSent = true
            
            // Focus the code input field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isTextFieldFocused = true
            }
        }
    }
    
    // Verify the entered code
    private func verifyCode() async {
        // Clear any previous errors
        errorMessage = nil
        
        guard verificationCode.count == 5, !verificationID.isEmpty else {
            if verificationCode.isEmpty {
                errorMessage = "Please enter the verification code"
            }
            return
        }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        if let currentUser = Auth.auth().currentUser {
            do {
                _ = try await currentUser.link(with: credential)
                await authViewModel.updateUserPhoneNumber(phoneNumber: phoneNumber)
                dismiss()
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

// Individual digit field for verification code
struct VerificationDigitField: View {
    let index: Int
    @Binding var code: String
    
    private let primaryColor = Color(red: 0.36, green: 0.42, blue: 0.26)
    private let textFieldBackground = Color(red: 0.92, green: 0.92, blue: 0.92)
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(textFieldBackground)
                .frame(width: 55, height: 70)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(code.count > index ? primaryColor : Color.clear, lineWidth: 2)
                )
            
            if code.count > index {
                let digit = String(code[code.index(code.startIndex, offsetBy: index)])
                Text(digit)
                    .font(.title)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
            }
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    PhoneVerificationView()
        .environmentObject(AuthViewModel())
}
