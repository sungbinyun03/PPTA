//
//  AuthViewModel.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import AuthenticationServices
import CryptoKit

protocol AuthenticationFormProtocol {
    var formIsValid: Bool { get }
}

@MainActor
class AuthViewModel: ObservableObject {
    @Published var userSession: FirebaseAuth.User?
    @Published var currentUser: User?
    fileprivate var currentNonce: String?
    
    init() {
        self.userSession = Auth.auth().currentUser
        
        Task {
            await fetchUser()
        }
    }

    // MARK: - Email/Password Authentication
    func signIn(withEmail email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.userSession = result.user
            await fetchUser()
        } catch {
            print("DEBUG: Failed to log in with error \(error.localizedDescription)")
        }
    }
    
    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        guard let topVC = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
            print("DEBUG: Failed to get top view controller.")
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: topVC)
            guard let idToken = result.user.idToken else {
                print("DEBUG: Failed to get ID token.")
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken.tokenString,
                                                           accessToken: result.user.accessToken.tokenString)

            let authResult = try await Auth.auth().signIn(with: credential)
            self.userSession = authResult.user
           
            // Check if user exists in Firestore
            let userRef = Firestore.firestore().collection("users").document(authResult.user.uid)
            let document = try? await userRef.getDocument()

            if document?.exists == false {
                // If user does not exist, create a new entry
                let newUser = User(id: authResult.user.uid,
                                   name: result.user.profile?.name ?? "Unknown",
                                   email: authResult.user.email ?? "No Email")

                let encodedUser = try Firestore.Encoder().encode(newUser)
                try await userRef.setData(encodedUser)
            }

            await fetchUser()
        } catch {
            print("DEBUG: Google Sign-In failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Apple Sign-In
    func handleSignInWithAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
    }

    func handleSignInWithAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        if case .failure(let failure) = result {
            print("DEBUG: Apple Sign-In failed: \(failure.localizedDescription)")
        } else if case .success(let success) = result {
            if let appleIDCredential = success.credential as? ASAuthorizationAppleIDCredential {
                guard let nonce = currentNonce else {
                    print("DEBUG: Missing nonce. Callback received without a request.")
                    return
                }
                guard let appleIDToken = appleIDCredential.identityToken else {
                    print("DEBUG: Missing identity token from Apple.")
                    return
                }
                guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                    print("DEBUG: Failed to decode ID token.")
                    return
                }

                let credential = OAuthProvider.appleCredential(
                    withIDToken: idTokenString,
                    rawNonce: nonce,
                    fullName: appleIDCredential.fullName
                )

                Task {
                    do {
                        let result = try await Auth.auth().signIn(with: credential)
                        self.userSession = result.user
                        print("DEBUG: Apple Sign-In successful. UID: \(result.user.uid)")

                        // Extract the user's name (if available) during the first sign-in
                        let userFullName = [
                            appleIDCredential.fullName?.givenName,
                            appleIDCredential.fullName?.familyName
                        ].compactMap { $0 }.joined(separator: " ")

                        // Save user to Firestore
                        let userRef = Firestore.firestore().collection("users").document(result.user.uid)
                        let document = try? await userRef.getDocument()
                        if document?.exists == false {
                            // Create a new user entry if it doesn't exist
                            let newUser = User(
                                id: result.user.uid,
                                name: userFullName.isEmpty ? "Unknown" : userFullName,
                                email: result.user.email ?? "No Email"
                            )
                            print(newUser)
                            let encodedUser = try Firestore.Encoder().encode(newUser)
                            try await userRef.setData(encodedUser)
                            print("DEBUG: New user added to Firestore.")
                        }
                        await fetchUser()
                    } catch {
                        print("DEBUG: Failed to sign in with Apple: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    // MARK: - User Management
    func createUser(withEmail email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            self.userSession = result.user
            let user = User(id: result.user.uid, name: name, email: email)
            let encodedUser = try Firestore.Encoder().encode(user)
            try await Firestore.firestore().collection("users").document(user.id).setData(encodedUser)
            await fetchUser()
        } catch {
            print("DEBUG: Failed to create user with error \(error.localizedDescription)")
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()  // Also sign out Google user
            self.userSession = nil
            self.currentUser = nil
        } catch {
            print("DEBUG: Failed to sign out with error \(error.localizedDescription)")
        }
    }

    func fetchUser() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            print("DEBUG: No user session found.")
            return
        }
        do {
            let snapshot = try await Firestore.firestore().collection("users").document(uid).getDocument()
            if let user = try? snapshot.data(as: User.self) {
                DispatchQueue.main.async {
                    self.currentUser = user
                    print("DEBUG: User fetched: \(user.name)")
                }
            } else {
                print("DEBUG: User not found in Firestore. Returning to login.")
                DispatchQueue.main.async {
                    self.userSession = nil  // Redirect to login
                }
            }
        } catch {
            print("DEBUG: Failed to fetch user: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.userSession = nil  // Redirect to login
            }
        }
    }}

// MARK: - Helpers for Apple Sign-In
private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    var randomBytes = [UInt8](repeating: 0, count: length)
    let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
    if errorCode != errSecSuccess {
        fatalError(
            "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
        )
    }

    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")

    let nonce = randomBytes.map { byte in
        // Pick a random character from the set, wrapping around if needed.
        charset[Int(byte) % charset.count]
    }

    return String(nonce)
}

private func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
    }.joined()

    return hashString
}
