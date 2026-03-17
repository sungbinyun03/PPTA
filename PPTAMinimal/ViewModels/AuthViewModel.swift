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
    static let shared = AuthViewModel()

    
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

    /// Sign in with email or phone number (resolves phone to email via Firestore) and password.
    func signIn(phoneOrEmail: String, password: String) async throws {
        let email: String
        if phoneOrEmail.contains("@") {
            email = phoneOrEmail
        } else {
            let normalized = UserRepository.normalizePhoneNumber(phoneOrEmail)
            guard normalized.count >= 10 else {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid email or phone number."])
            }
            do {
                guard let user = try await userRepository.findUserByPhone(normalized) else {
                    throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "No account found for this phone number."])
                }
                email = user.email
            } catch {
                throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "We couldn't look up your account. Check your connection and try again."])
            }
        }
        let firebaseUser = try await authService.signIn(withEmail: email, password: password)
        self.userSession = firebaseUser
        await fetchUser()
    }
    
    /// Returns true if the phone number is already registered to another account (optionally exclude one uid, e.g. current user when updating).
    func isPhoneNumberTaken(_ phoneNumber: String, excludingUid: String? = nil) async throws -> Bool {
        let normalized = UserRepository.normalizePhoneNumber(phoneNumber)
        guard normalized.count >= 10 else { return false }
        guard let existing = try await userRepository.findUserByPhone(normalized) else { return false }
        if let exclude = excludingUid, existing.id == exclude { return false }
        return true
    }

    func createUser(withEmail email: String, password: String, name: String, phoneNumber: String) async throws {
        let normalized = UserRepository.normalizePhoneNumber(phoneNumber)
        guard normalized.count >= 10 else { throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "Please enter a valid phone number"]) }
        if try await isPhoneNumberTaken(normalized) {
            throw NSError(domain: "Auth", code: -1, userInfo: [NSLocalizedDescriptionKey: "This phone number is already registered to another account."])
        }
        let firebaseUser = try await authService.createUser(withEmail: email, password: password)
        self.userSession = firebaseUser
        
        let newUser = User(id: firebaseUser.uid, name: name, email: email, phoneNumber: normalized, fcmToken: nil)
        try await userRepository.saveUser(newUser)
        
        let defaultSettings = UserSettings(
            thresholdHour: 1,
            thresholdMinutes: 0,
            onboardingCompleted: false,
            peerCoaches: []
        )
        UserSettingsManager.shared.saveSettings(defaultSettings)

        await fetchUser()
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
        guard let uid = authService.currentUser?.uid else {
            self.userSession = nil
            return
        }
        do {
            self.currentUser = try await userRepository.fetchUser(by: uid)
            // If there's a stored FCM token from before login
            if let storedToken = UserDefaults.standard.string(forKey: "fcmToken") {
                await updateFCMToken(storedToken)
                UserDefaults.standard.removeObject(forKey: "fcmToken")
            }
        } catch {
            print("DEBUG: fetchUser error: \(error.localizedDescription)")
            DispatchQueue.main.async { self.userSession = nil }
        }
    }
    
    func updateUserPhoneNumber(phoneNumber: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        let normalized = UserRepository.normalizePhoneNumber(phoneNumber)
        guard normalized.count >= 10 else { return }
        try? await userRepository.updateUserField(uid: uid, field: "phoneNumber", value: normalized)
        await fetchUser()
    }
    
    func updateFCMToken(_ token: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        try? await userRepository.updateUserField(
            uid: uid, field: "fcmToken", value: token)
        print(" Firestore ✅: Successfully updated FCM token for UID \(uid) to: \(token)")
        await fetchUser()
    }
    
    func signOut() {
        do { try authService.signOut(); googleSignInService.signOut(); self.userSession = nil; self.currentUser = nil }
        catch { print("DEBUG: signOut error: \(error.localizedDescription)") }
    }

    /// Returns a short, user-friendly error message (no codes or technical jargon).
    static func userFacingMessage(for error: Error) -> String {
        let ns = error as NSError
        if ns.domain == "Auth", let msg = ns.userInfo[NSLocalizedDescriptionKey] as? String, !msg.isEmpty {
            return msg
        }
        // Only interpret as Firebase Auth errors when from Auth domain (avoid passing Firestore/other errors into AuthErrorCode)
        if ns.domain == "FIRAuthErrorDomain" {
            let authCode = AuthErrorCode(_bridgedNSError: ns)
            switch authCode {
            case .wrongPassword:
                return "Incorrect password. Please try again."
            case .userNotFound:
                return "No account found with this email or phone."
            case .emailAlreadyInUse:
                return "This email is already in use by another account."
            case .invalidEmail:
                return "Please enter a valid email address."
            case .weakPassword:
                return "Password should be at least 6 characters."
            case .tooManyRequests:
                return "Too many attempts. Please try again later."
            case .networkError:
                return "Check your connection and try again."
            case .invalidVerificationCode:
                return "Invalid verification code. Please try again."
            case .invalidVerificationID:
                return "Verification expired. Please request a new code."
            case .credentialAlreadyInUse:
                return "This phone number is already linked to another account."
            default:
                break
            }
        }
        // Network/connectivity
        if ns.domain == NSURLErrorDomain || ns.domain == "FIRFirestoreErrorDomain" {
            return "Check your connection and try again."
        }
        return "Something went wrong. Please try again."
    }
    
    func updateUserDisplayName(displayName: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        
        do {
            try await userRepository.updateUserField(uid: uid, field: "name", value: displayName)
            await fetchUser() // Refresh the current user data
        } catch {
            print("DEBUG: Failed to update display name: \(error.localizedDescription)")
        }
    }
}
