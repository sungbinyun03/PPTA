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
    
    @Environment(\.dismiss) var dismiss
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Verify Your Phone Number")
                    .font(.headline)
                
                if !isCodeSent {
                    TextField("+1XXXXXXXXXX", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Send Code") {
                        Task {
                            await sendVerificationCode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                } else {
                    TextField("Enter 6-digit code", text: $verificationCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Verify Code") {
                        Task {
                            await verifyCode()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    private func sendVerificationCode() async {
        guard !phoneNumber.isEmpty else { return }
        let numberWithCountry = "+1\(phoneNumber)"
        

        PhoneAuthProvider.provider().verifyPhoneNumber(numberWithCountry, uiDelegate: nil){
            (verificationID, error) in
            if let error = error {
                print("Error details: \(error.localizedDescription)")
                        print("Debug error info: \(error)") 
                self.errorMessage = error.localizedDescription
                return
            }
            guard let verificationID = verificationID else {
                print("Failed to get verification ID")
                return
            }
            self.verificationID = verificationID
            self.isCodeSent = true
       
        }
       
    }
    
    private func verifyCode() async {
        guard !verificationCode.isEmpty, !verificationID.isEmpty else { return }
        
        let credential = PhoneAuthProvider.provider().credential(
            withVerificationID: verificationID,
            verificationCode: verificationCode
        )
        
        guard let currentUser = Auth.auth().currentUser else {
            self.errorMessage = "No current user found."
            return
        }
        
        do {
            _ = try await currentUser.link(with: credential)
            await authViewModel.updateUserPhoneNumber(phoneNumber: phoneNumber)
            
            dismiss()
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }
}
