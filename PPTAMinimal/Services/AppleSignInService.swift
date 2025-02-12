//
//  AppleSignInService.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 2/10/25.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth

class AppleSignInService: NSObject {
    
    private var currentNonce: String?
    
    /// Configures the `ASAuthorizationAppleIDRequest` with the required nonce and scopes.
    func configure(request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }
    
    /// Handles the completion of Apple Sign-In. Returns a Firebase `AuthCredential` if successful.
    func handleCompletion(_ result: Result<ASAuthorization, Error>) async throws -> AuthCredential? {
        switch result {
        case .failure(let error):
            print("DEBUG: Apple Sign-In failed: \(error.localizedDescription)")
            return nil
            
        case .success(let auth):
            guard
                let appleIDCredential = auth.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce,
                let appleIDToken = appleIDCredential.identityToken,
                let idTokenString = String(data: appleIDToken, encoding: .utf8)
            else {
                print("DEBUG: Missing or invalid Apple ID credential.")
                return nil
            }
            
            // Convert Apple credential to a Firebase credential
            return OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
        }
    }
}

// MARK: - Helpers: Nonce Generation and SHA-256

/// Adapted from Apple's sample code to generate a random nonce string.
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
    }

    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    
    // Map each random byte to a random character in the charset
    let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
    }

    return String(nonce)
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()
}
