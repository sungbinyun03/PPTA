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
import FirebaseMessaging
import GoogleSignIn
import AuthenticationServices
import CryptoKit


protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    /// DEV TOGGLE — force the full "fresh install" onboarding flow, ignoring the per-user completion
    /// flag, Firestore setup state, and reinstall detection, so you can exercise the fresh flow on an
    /// already-set-up account. When true, `applyOnboardingRoute` routes to full onboarding; once
    /// the run completes, `markOnboardingComplete()` lets the app fall through to the main tabs (a
    /// relaunch re-forces fresh). MUST be `false` for release builds.
    static let devManualFreshOnboard = false

    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    @Published var isOnboardingComplete: Bool = false

    /// The uid whose onboarding route has already been decided this session. Routing is decided
    /// once per sign-in, not on every `fetchUser()` — which also runs on phone verification, FCM
    /// token refreshes, etc. Re-deciding mid-run once skipped Find Coach by swapping the flow
    /// partway through; one decision per sign-in keeps a run stable.
    private var routedUID: String?

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

    /// Loads the user's Firestore settings into `UserSettingsManager`. Hydrates `coachIds`/`traineeIds`
    /// early so onboarding's App Limits save writes the *real* settings object instead of
    /// overwriting relationships with empties (that screen also re-checks before saving).
    ///
    /// Routing no longer depends on this: every user without the per-device onboarding flag —
    /// brand-new account, reinstall, or a new phone — gets the same full flow. (There used to be a
    /// trimmed "reconfigure" flow for reinstalls.) The reinstall notice to coaches is independent —
    /// `ReinstallDetector`, keyed off a Keychain marker.
    private func hydrateSettings(uid: String) {
        let manager = UserSettingsManager.shared
        // `id == uid` means the in-memory copy already belongs to this user. For a brand-new user
        // with no doc yet, `loadSettings` may not call back at all — there's nothing to hydrate.
        guard manager.userSettings.id != uid else { return }
        manager.loadSettings { loaded in
            Task { @MainActor in manager.userSettings = loaded }
        }
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
            } else if routedUID != uid {
                // First successful load for this account this session: decide the route once.
                routedUID = uid
                let localFlag = UserDefaults.standard.bool(forKey: "onboardingComplete_\(uid)")
                // The per-device flag alone decides: no flag → the full onboarding flow, whether
                // this is a new account, a reinstall, or a new phone. The dev fresh-onboard toggle
                // forces the full flow even when the flag is set.
                isOnboardingComplete = Self.devManualFreshOnboard ? false : localFlag
                hydrateSettings(uid: uid)

                // If this launch is a reinstall by the same user, quietly report it to their coaches.
                // Runs at most once per launch even though fetchUser() is called repeatedly.
                ReinstallDetector.handleAuthenticated(uid: uid)
            }
            if let storedToken = UserDefaults.standard.string(forKey: "fcmToken") {
                await updateFCMToken(storedToken)
                UserDefaults.standard.removeObject(forKey: "fcmToken")
            }
        } catch {
            print("DEBUG: fetchUser error: \(error.localizedDescription)")
            await handleFetchUserFailure(error, uid: uid)
        }
    }

    /// Decides what a failed `users/<uid>` read means for the session.
    ///
    /// This used to clear `userSession` unconditionally, which signed the user out to `LoginView`
    /// on any offline read, timeout or rules blip — and offline they can't sign back in, so a
    /// dropped connection at launch was indistinguishable from the account being gone. A Firestore
    /// failure is no evidence about the account; the only authority on that is Firebase Auth, so we
    /// ask it before clearing anything.
    private func handleFetchUserFailure(_ error: Error, uid: String) async {
        if await accountNoLongerExists() {
            self.currentUser = nil
            self.userSession = nil
            return
        }
        // Transient. Keep the session, and route from the device-local flag so an offline launch
        // puts an already-set-up user back where they were instead of at the start of onboarding.
        let localFlag = UserDefaults.standard.bool(forKey: "onboardingComplete_\(uid)")
        isOnboardingComplete = Self.devManualFreshOnboard ? false : localFlag
        // Running on a stale profile is "definitely broken", so it has to be visible — the old
        // behaviour was the same failure with the session thrown away and nothing said.
        NotificationManager.shared.showInAppMessage(
            title: "Couldn't load your account",
            body: Self.userFacingMessage(for: error),
            dismissAfter: 5
        )
    }

    /// Asks Firebase Auth whether the account behind this session is really gone — the only
    /// condition that may end a session here.
    ///
    /// One `reload()`, no retry loop: it re-reads the account from the Auth backend and only its
    /// "deleted / disabled / credentials revoked" codes count as terminal. A network error is the
    /// same outage that broke the Firestore read, so it answers `false` and the session survives.
    private func accountNoLongerExists() async -> Bool {
        guard let user = authService.currentUser else { return true }
        do {
            try await user.reload()
            return false
        } catch {
            let ns = error as NSError
            guard ns.domain == "FIRAuthErrorDomain" else { return false }
            return Self.accountGoneAuthCodes.contains(ns.code)
        }
    }

    /// Auth codes that mean this session can never work again: account deleted (17011), disabled
    /// (17005), token revoked (17017), refresh credentials expired (17021).
    private static let accountGoneAuthCodes: Set<Int> = [
        AuthErrorCode.userNotFound.rawValue,
        AuthErrorCode.userDisabled.rawValue,
        AuthErrorCode.invalidUserToken.rawValue,
        AuthErrorCode.userTokenExpired.rawValue
    ]

    func updateUserPhoneNumber(phoneNumber: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        let normalized = UserRepository.normalizePhoneNumber(phoneNumber)
        guard normalized.count >= 10 else { return }
        try? await userRepository.updateUserField(uid: uid, field: "phoneNumber", value: normalized)
        await fetchUser()
    }
    
    func updateFCMToken(_ token: String) async {
        guard let uid = authService.currentUser?.uid else { return }
        // `updateData`, not a merge-write: this fires whenever Firebase rotates the token, including
        // after an account was just deleted, and a merge-write would recreate `users/<uid>` holding
        // only `fcmToken`. If the doc doesn't exist yet at signup, `registerFCMToken()` (called right
        // after the doc is created on every signup path) writes the token instead.
        try? await userRepository.updateUserField(uid: uid, field: "fcmToken", value: token)
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
        let uid = authService.currentUser?.uid
        Task { @MainActor in
            await clearFCMToken(uid: uid)
            do { try authService.signOut(); googleSignInService.signOut(); self.userSession = nil; self.currentUser = nil; self.routedUID = nil }
            catch { print("DEBUG: signOut error: \(error.localizedDescription)") }
        }
    }

    /// Removes this user's `fcmToken` so pushes aimed at them stop reaching a phone someone else
    /// is about to sign in on. It has to land *while still signed in* (a write queued across a
    /// sign-out is held for that user and could erase the token they register next time), so
    /// `signOut` waits for it, but only briefly: offline it must not hold sign-out hostage. Pushes
    /// also carry their target uid, which the app checks, so this is the second line, not the first.
    private func clearFCMToken(uid: String?) async {
        guard let uid else { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // `updateData` so clearing never creates an empty doc for a deleted account.
                try? await self.userRepository.updateUserField(uid: uid, field: "fcmToken", value: FieldValue.delete())
            }
            group.addTask { try? await Task.sleep(nanoseconds: 3_000_000_000) }
            await group.next()
            group.cancelAll()
        }
    }

    /// "Cancel sign up". Runs the same full deletion as Settings → Delete Account.
    ///
    /// It used to delete the two docs and call `firebaseUser.delete()` client-side, which (a) usually
    /// failed silently with "requires recent login", orphaning the Auth account, (b) never signed out
    /// of Firebase Auth, so the Keychain-persisted session lived on and the next FCM token refresh
    /// recreated `users/<uid>` holding only `fcmToken`, and (c) by this point in onboarding left the
    /// profile picture, App Limits and running Screen Time monitoring behind. The server function
    /// cascades everything and deletes the Auth record with admin rights; `finishAccountDeletion`
    /// stops monitoring, clears local state and signs out.
    func deleteIncompleteAccount() {
        Task { @MainActor in
            do {
                try await deleteAccount()
            } catch {
                // Couldn't reach the server: at least end the session so nothing keeps writing.
                print("DEBUG: deleteIncompleteAccount failed: \(error)")
                DeviceActivityManager.shared.stopAllMonitoring()
                signOut()
            }
        }
    }

    // MARK: - Account Deletion

    /// Permanently deletes the signed-in user's account and all associated data.
    ///
    /// Delegates to the `deleteAccount` Cloud Run function, which authenticates the caller via
    /// their Firebase ID token, cascades cleanup across Firestore (own docs, friendships,
    /// roleRequests, other users' coachIds/traineeIds) and Storage, then deletes the Auth
    /// record server-side with admin privileges — no client re-authentication needed.
    func deleteAccount() async throws {
        guard let uid = Auth.auth().currentUser?.uid else { signOut(); return }
        let client = CloudRunHTTPClient(baseURL: CloudRunConfig.deleteAccountURL)
        try await client.postJSON("", body: [:])
        finishAccountDeletion(uid: uid)
    }

    /// Tears down local state after the account has been deleted, then signs out.
    private func finishAccountDeletion(uid: String) {
        // Stop screen-time enforcement and lift any shield that is up: stopping monitoring alone
        // leaves a raised shield standing, with nothing left that would ever lower it.
        DeviceActivityManager.shared.stopAllMonitoring()
        DeviceActivityManager.shared.clearShield()

        // Clear per-user onboarding flag and the shared app-group snapshot.
        UserDefaults.standard.removeObject(forKey: "onboardingComplete_\(uid)")
        let suite = UserDefaults(suiteName: "group.com.sungbinyun.com.PPTADev")
        suite?.removeObject(forKey: "UserSettings")
        suite?.removeObject(forKey: "CurrentUserId")

        googleSignInService.signOut()
        // Sign out of Firebase Auth too: the Auth record is gone server-side, but the SDK's
        // local session/token cache needs to be cleared explicitly.
        try? authService.signOut()
        self.userSession = nil
        self.currentUser = nil
        self.isOnboardingComplete = false
        self.routedUID = nil
    }

    /// Returns a short, user-friendly error message (no codes or technical jargon).
    static func userFacingMessage(for error: Error) -> String {
        // Cloud Run handlers return already-user-facing text in `{"error": "..."}`.
        if let clientError = error as? CloudRunHTTPClient.ClientError,
           let message = clientError.serverMessage {
            return message
        }

        let ns = error as NSError
        if ns.domain == "Auth", let msg = ns.userInfo[NSLocalizedDescriptionKey] as? String, !msg.isEmpty {
            return msg
        }
        // Only interpret as Firebase Auth errors when from Auth domain (avoid passing Firestore/other errors into AuthErrorCode)
        // Look the code up by raw value. `AuthErrorCode(_bridgedNSError:)` returns nil for these
        // errors in Firebase 11 (`AuthErrorCode` is a plain Int enum whose bridged domain isn't
        // "FIRAuthErrorDomain"), which silently sent every case below to the generic message.
        if ns.domain == "FIRAuthErrorDomain", let authCode = AuthErrorCode(rawValue: ns.code) {
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
                return "Too many verification attempts from this device. Please wait a while and try again."
            case .networkError:
                return "Check your connection and try again."
            case .invalidVerificationCode:
                return "Invalid verification code. Please try again."
            case .invalidVerificationID:
                return "Verification expired. Please request a new code."
            case .credentialAlreadyInUse:
                return "This phone number is already linked to another account."
            case .invalidPhoneNumber, .missingPhoneNumber:
                return "That phone number doesn't look right. Check the country code and number."
            case .quotaExceeded:
                return "We've hit our text message limit for now. Please try again later."
            case .captchaCheckFailed, .webContextCancelled:
                return "Verification was interrupted. Please try again."
            case .appNotAuthorized, .invalidAppCredential, .missingAppCredential, .notificationNotForwarded:
                return "Phone verification couldn't start on this device. Please try again in a moment."
            default:
                break
            }
        }
        // Network/connectivity
        if ns.domain == NSURLErrorDomain || ns.domain == "FIRFirestoreErrorDomain" {
            return "Check your connection and try again."
        }
        #if DEBUG
        // Surface the real cause while testing; release builds keep the friendly copy.
        return "Something went wrong (\(ns.domain) \(ns.code)). Please try again."
        #else
        return "Something went wrong. Please try again."
        #endif
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
