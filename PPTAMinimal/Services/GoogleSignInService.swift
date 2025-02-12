//
//  GoogleSignInService.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 2/10/25.
//

import GoogleSignIn
import FirebaseAuth
import Foundation
import UIKit

enum GoogleSignInError: Error {
    case missingIdToken
}

class GoogleSignInService {

    /// Presents the Google sign-in flow from the given UIViewController.
    /// Returns a Firebase AuthCredential to pass to AuthService.
    func signIn(withPresenting viewController: UIViewController) async throws -> AuthCredential {
        // 1. Show Google Sign-In flow
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        
        // 2. Ensure we got a valid ID token
        guard let idToken = result.user.idToken else {
            throw GoogleSignInError.missingIdToken
        }
        
        // 3. Create the Firebase credential
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken.tokenString,
            accessToken: result.user.accessToken.tokenString
        )
        return credential
    }

    /// Signs out from the Google session to keep things in sync with Firebase sign-out.
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
    }
}
