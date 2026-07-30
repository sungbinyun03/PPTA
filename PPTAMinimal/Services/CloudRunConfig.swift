//
//  CloudRunConfig.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation

enum CloudRunConfig {
    /// Set this to your deployed Cloud Run service URL (us-central1).
    /// Example: `https://your-function-url-uc.a.run.app`
    ///
    /// This is a **single endpoint** function; the iOS app posts JSON with an `"action"` field.
    static let roleRequestsBaseURL = URL(string: "https://role-requests-538124351649.us-central1.run.app/roleRequests")!

    /// Deletes the caller's account (Firestore cascade cleanup + Firebase Auth record).
    /// Authenticates via `Authorization: Bearer <Firebase ID token>`; server derives the uid
    /// from the verified token, so this call can only ever delete the caller's own account.
    static let deleteAccountURL = URL(string: "https://deleteaccount-538124351649.us-central1.run.app")!
}


