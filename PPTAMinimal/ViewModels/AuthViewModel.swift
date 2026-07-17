//
//  AuthViewModel.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import FirebaseMessaging
import GoogleSignIn
import AuthenticationServices
import CryptoKit


protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

/// Errors surfaced by the account-deletion flow.
enum AccountDeletionError: LocalizedError {
    /// Firebase requires a recent login before it will delete the Auth record.
    /// `providerID` is the user's sign-in provider ("password", "google.com", "apple.com")
    /// so the UI can present the correct re-authentication path.
    case reauthRequired(providerID: String)

    var errorDescription: String? {
        switch self {
        case .reauthRequired:
            return "For your security, please confirm it's you to finish deleting your account."
        }
    }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isOnboardingComplete: Bool = false
    
    private let authService: AuthService
    private let userRepository: UserRepository
    private let googleSignInService: GoogleSignInService
    private let appleSignInService: AppleSignInService
    private let friendshipRepository: FriendshipRepository
    private let roleRequestRepository: RoleRequestRepository
    static let shared = AuthViewModel()


    init(
        authService: AuthService = AuthService(),
        userRepository: UserRepository = UserRepository(),
        googleSignInService: GoogleSignInService = GoogleSignInService(),
        appleSignInService: AppleSignInService = AppleSignInService(),
        friendshipRepository: FriendshipRepository = FriendshipRepository(),
        roleRequestRepository: RoleRequestRepository = RoleRequestRepository()
    ) {
        self.authService = authService
        self.userRepository = userRepository
        self.googleSignInService = googleSignInService
        self.appleSignInService = appleSignInService
        self.friendshipRepository = friendshipRepository
        self.roleRequestRepository = roleRequestRepository
        
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
        await registerFCMToken()

        // New users: Off pressure, 0h 0m limit, no apps (see UserSettings init defaults).
        let defaultSettings = UserSettings(
            thresholdHour: 0,
            thresholdMinutes: 0,
            pressureLevel: PressureLevel.off,
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
                UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(firebaseUser.uid)")
                let newUser = User(
                    id: firebaseUser.uid,
                    name: firebaseUser.displayName ?? "Unknown",
                    email: firebaseUser.email ?? "No Email"
                )
                try await userRepository.saveUser(newUser)
                await registerFCMToken()
                let defaultSettings = UserSettings(
                    thresholdHour: 0,
                    thresholdMinutes: 0,
                    pressureLevel: PressureLevel.off,
                    onboardingCompleted: false,
                    peerCoaches: []
                )
                UserSettingsManager.shared.saveSettings(defaultSettings)
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
                    UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(firebaseUser.uid)")
                    let fullName = extractAppleFullName(from: result)
                    let newUser = User(
                        id: firebaseUser.uid,
                        name: fullName.isEmpty ? "Unknown" : fullName,
                        email: firebaseUser.email ?? "No Email"
                    )
                    try await userRepository.saveUser(newUser)
                    await registerFCMToken()
                    let defaultSettings = UserSettings(
                        thresholdHour: 0,
                        thresholdMinutes: 0,
                        pressureLevel: PressureLevel.off,
                        onboardingCompleted: false,
                        peerCoaches: []
                    )
                    UserSettingsManager.shared.saveSettings(defaultSettings)
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

    
    func markOnboardingComplete() {
        guard let uid = userSession?.uid else { return }
        UserDefaults.standard.set(true, forKey: "onboardingComplete_\(uid)")
        isOnboardingComplete = true
    }

    func fetchUser() async {
        guard let uid = authService.currentUser?.uid else {
            self.userSession = nil
            return
        }
        do {
            self.currentUser = try await userRepository.fetchUser(by: uid)
            if self.currentUser == nil {
                // Firestore doc was deleted (e.g. data reset) — clear stale onboarding flag
                UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(uid)")
                isOnboardingComplete = false
            } else {
                isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete_\(uid)")
            }
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
        // Merge-write so this succeeds even if the user doc was just created (or not yet fully written).
        try? await userRepository.setUserFields(uid: uid, ["fcmToken": token])
        print(" Firestore ✅: Successfully updated FCM token for UID \(uid) to: \(token)")
        await fetchUser()
    }

    /// Fetches the current FCM registration token on demand and hydrates it to Firestore.
    ///
    /// Called right after account creation. The `didReceiveRegistrationToken` callback often
    /// fires *before* the user is signed in (token dropped) or *before* `users/<uid>` exists
    /// (write fails), leaving fresh users with no `fcmToken` — which then crashes the lock/unlock
    /// Cloud Functions. Pulling the token via `Messaging.token()` here doesn't depend on that
    /// callback, and the merge-write can't fail on a missing/partial doc.
    func registerFCMToken() async {
        guard let uid = authService.currentUser?.uid else { return }
        do {
            let token = try await Messaging.messaging().token()
            try await userRepository.setUserFields(uid: uid, ["fcmToken": token])
            print(" Firestore ✅: Hydrated FCM token post-signup for UID \(uid)")
        } catch {
            print("DEBUG: registerFCMToken error: \(error.localizedDescription)")
        }
    }
    
    func signOut() {
        do { try authService.signOut(); googleSignInService.signOut(); self.userSession = nil; self.currentUser = nil }
        catch { print("DEBUG: signOut error: \(error.localizedDescription)") }
    }

    func deleteIncompleteAccount() {
        Task {
            guard let firebaseUser = Auth.auth().currentUser else { signOut(); return }
            let uid = firebaseUser.uid
            try? await userRepository.deleteUser(uid: uid)
            try? await Firestore.firestore().collection("userSettings").document(uid).delete()
            try? await firebaseUser.delete()
            await MainActor.run {
                googleSignInService.signOut()
                self.userSession = nil
                self.currentUser = nil
            }
        }
    }

    // MARK: - Account Deletion

    /// The sign-in provider of the current user ("password", "google.com", "apple.com").
    var currentAuthProviderID: String? {
        Auth.auth().currentUser?.providerData.first?.providerID
    }

    /// Permanently deletes the signed-in user's account and all associated data.
    ///
    /// All Firestore / Storage / relationship cleanup runs *while still authenticated*;
    /// the Firebase Auth record is deleted **last**. If Firebase requires a recent login,
    /// throws `AccountDeletionError.reauthRequired` so the caller can collect fresh
    /// credentials and retry via `reauthenticateAndDeleteAccount(with:)`.
    func deleteAccount() async throws {
        guard let firebaseUser = Auth.auth().currentUser else { signOut(); return }
        try await performAccountDeletion(firebaseUser: firebaseUser)
    }

    /// Re-authenticates with a fresh credential, then deletes the account.
    /// Called by the UI after collecting credentials in response to `reauthRequired`.
    func reauthenticateAndDeleteAccount(with credential: AuthCredential) async throws {
        guard let firebaseUser = Auth.auth().currentUser else { signOut(); return }
        try await firebaseUser.reauthenticate(with: credential)
        try await performAccountDeletion(firebaseUser: firebaseUser)
    }

    /// Runs the Apple re-authentication flow from a `SignInWithAppleButton` completion,
    /// then deletes the account.
    func reauthenticateWithAppleCompletion(_ result: Result<ASAuthorization, Error>) async throws {
        guard let credential = try await appleSignInService.handleCompletion(result) else {
            throw NSError(domain: "Auth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Apple sign-in failed. Please try again."])
        }
        try await reauthenticateAndDeleteAccount(with: credential)
    }

    /// Presents Google sign-in and returns a fresh credential for re-authentication.
    func googleReauthCredential() async throws -> AuthCredential {
        guard let topVC = topViewController() else {
            throw NSError(domain: "Auth", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Couldn't present Google sign-in."])
        }
        return try await googleSignInService.signIn(withPresenting: topVC)
    }

    private func performAccountDeletion(firebaseUser: FirebaseAuth.User) async throws {
        let uid = firebaseUser.uid

        // 1. Best-effort cascade cleanup — while still authenticated.
        await cascadeDeleteUserData(uid: uid)

        // 2. Delete the Firebase Auth record (the crux).
        do {
            try await firebaseUser.delete()
        } catch {
            let ns = error as NSError
            guard ns.domain == "FIRAuthErrorDomain" else { throw error }
            let authCode = AuthErrorCode(_bridgedNSError: ns)
            switch authCode {
            case .requiresRecentLogin:
                throw AccountDeletionError.reauthRequired(
                    providerID: firebaseUser.providerData.first?.providerID ?? "password")
            default:
                throw error
            }
        }

        // 3. Local cleanup + sign out (root view switches to LoginView on userSession == nil).
        finishAccountDeletion(uid: uid)
    }

    /// Removes everything that references this user across Firestore and Storage.
    /// Each step is best-effort so a single failure doesn't block the rest of the deletion.
    private func cascadeDeleteUserData(uid: String) async {
        let settings = UserSettingsManager.shared.userSettings

        // Dissolve peer relationships server-side (scrubs the *other* user's coachIds/traineeIds).
        // role .coach: `otherId` is my trainee; role .trainee: `otherId` is my coach.
        for traineeId in settings.traineeIds {
            try? await roleRequestRepository.removeRelationship(otherId: traineeId, role: .coach)
        }
        for coachId in settings.coachIds {
            try? await roleRequestRepository.removeRelationship(otherId: coachId, role: .trainee)
        }

        // Delete pending friend + role requests involving this user.
        try? await friendshipRepository.deleteAllInvolving(uid: uid)
        try? await roleRequestRepository.deleteAllInvolving(uid: uid)

        // Delete the profile image blob (no-op if none exists).
        try? await Storage.storage().reference(withPath: "profilePictures/\(uid).jpg").delete()

        // Delete this user's own Firestore documents.
        try? await userRepository.deleteUser(uid: uid)
        try? await Firestore.firestore().collection("userSettings").document(uid).delete()
    }

    /// Tears down local state after the account has been deleted, then signs out.
    private func finishAccountDeletion(uid: String) {
        // Stop screen-time enforcement so no shields linger for a deleted account.
        DeviceActivityManager.shared.stopAllMonitoring()

        // Clear per-user onboarding flag and the shared app-group snapshot.
        UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(uid)")
        let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
        suite?.removeObject(forKey: "UserSettings")
        suite?.removeObject(forKey: "CurrentUserId")

        googleSignInService.signOut()
        self.userSession = nil
        self.currentUser = nil
        self.isOnboardingComplete = false
    }

    /// Returns the top-most presented view controller for presenting provider sign-in flows.
    private func topViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow })?.rootViewController
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
