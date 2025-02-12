//
//  AuthService.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 2/10/25.
//

import Firebase
import FirebaseAuth
import Foundation

class AuthService {

    /// Returns the currently signed-in Firebase user, if any.
    var currentUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    /// Signs in an existing user with email and password.
    func signIn(withEmail email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    /// Creates a new user with email and password.
    func createUser(withEmail email: String, password: String) async throws -> FirebaseAuth.User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    /// Signs in with a given Firebase Auth credential (e.g., from Google or Apple).
    func signIn(with credential: AuthCredential) async throws -> FirebaseAuth.User {
        let authResult = try await Auth.auth().signIn(with: credential)
        return authResult.user
    }

    /// Signs out the current user.
    func signOut() throws {
        try Auth.auth().signOut()
    }
}
