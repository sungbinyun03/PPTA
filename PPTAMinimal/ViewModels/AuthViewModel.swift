//
//  AuthViewModel.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import GoogleSignIn
import AuthenticationServices
import CryptoKit

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    
    private let authService: AuthService
    private let userRepository: UserRepository
    private let googleSignInService: GoogleSignInService
    private let appleSignInService: AppleSignInService
    
    init(
        authService: AuthService = AuthService(),
        userRepository: UserRepository = UserRepository(),
        googleSignInService: GoogleSignInService = GoogleSignInService(),
        appleSignInService: AppleSignInService = AppleSignInService()
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.googleSignInService = googleSignInService
        self.appleSignInService = appleSignInService
        
        self.userSession = authService.currentUser
        Task { await fetchUser() }
    }
    
    func signIn(withEmail email: String, password: String) async {
        do {
            let firebaseUser = try await authService.signIn(withEmail: email, password: password)
            self.userSession = firebaseUser
            await fetchUser()
        } catch { print("DEBUG: signIn error: \(error.localizedDescription)") }
    }
    
    func createUser(withEmail email: String, password: String, name: String) async {
        do {
            let firebaseUser = try await authService.createUser(withEmail: email, password: password)
            self.userSession = firebaseUser
            
            let newUser = User(id: firebaseUser.uid, name: name, email: email, phoneNumber: nil, fcmToken: nil)
            try await userRepository.saveUser(newUser)
            
            await fetchUser()
        } catch { print("DEBUG: createUser error: \(error.localizedDescription)") }
    }
    
    // MARK: - Google Sign-In
        /// Orchestrates Google Sign-In flow, obtains Firebase credential, then signs in.
    func signInWithGoogle() async {
        // 1. We need a UIViewController to present the GoogleSignIn flow
        guard let topVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            print("DEBUG: Failed to get top view controller.")
            return
        }

        do {
            // 2. Get the Firebase credential via GoogleSignInService
            let credential = try await googleSignInService.signIn(withPresenting: topVC)

            // 3. Sign in with the credential using AuthService
            let firebaseUser = try await authService.signIn(with: credential)
            self.userSession = firebaseUser

            // 4. If this is a first-time user, create their Firestore record
            let exists = try await userRepository.userExists(firebaseUser.uid)
            if !exists {
                let newUser = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "Unknown",
                    email: firebaseUser.email ?? "No Email"
                )
                try await userRepository.saveUser(newUser)
            }

            await fetchUser()
        } catch {
            print("DEBUG: Google Sign-In error: \(error.localizedDescription)")
        }
    }
    
    
    // MARK: - Apple Sign-In
        
    /// Called to prepare the AppleSignIn request with the correct nonce and scopes.
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        appleSignInService.configure(request: request)
    }

    /// Called from the Apple sign-in completion handler.
    /// We convert the result into a Firebase credential and sign in.
    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        Task {
            do {
                guard let credential = try await appleSignInService.handleCompletion(result) else {
                    print("DEBUG: Apple credential is nil.")
                    return
                }
                // Sign in to Firebase with the Apple credential
                let firebaseUser = try await authService.signIn(with: credential)
                self.userSession = firebaseUser
                
                print("CHECK 0")

                let exists = try await userRepository.userExists(firebaseUser.uid)
                if !exists {
                    // If user doesn't exist in Firestore, create a new record
                    let fullName = extractAppleFullName(from: result)
                    let newUser = User(
                        id: firebaseUser.uid,
                        name: fullName.isEmpty ? "Unknown" : fullName,
                        email: firebaseUser.email ?? "No Email"
                    )
                    try await userRepository.saveUser(newUser)
                }
                
                print("CHECK 1")

                await fetchUser()
            } catch {
                print("DEBUG: Apple Sign-In error: \(error.localizedDescription)")
            }
        }
    }

    /// Building the user’s name from the AppleIDCredential.
    private func extractAppleFullName(from result: Result<ASAuthorization, Error>) -> String {
        switch result {
        case .success(let auth):
            if let credential = auth.credential as? ASAuthorizationAppleIDCredential {
                let parts = [
                    credential.fullName?.givenName,
                    credential.fullName?.familyName
                ]
                return parts.compactMap { $0 }.joined(separator: " ")
            }
        case .failure:
            break
        }
        return ""
    }

    
    func fetchUser() async {
        guard let uid = authService.currentUser?.uid else { return }
        do { self.currentUser = try await userRepository.fetchUser(by: uid) } catch { print("DEBUG: fetchUser error: \(error.localizedDescription)") }
    }
    
    func updateUserPhoneNumber(phoneNumber: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        try? await userRepository.updateUserField(uid: uid, field: "phoneNumber", value: phoneNumber)
        await fetchUser()
    }
    
    func updateFCMToken(_ token: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        try? await userRepository.updateUserField(uid: uid, field: "fcmToken", value: token)
        await fetchUser()
    }
    
    func signOut() {
        do { try authService.signOut(); googleSignInService.signOut(); self.userSession = nil; self.currentUser = nil }
        catch { print("DEBUG: signOut error: \(error.localizedDescription)") }
    }
}
