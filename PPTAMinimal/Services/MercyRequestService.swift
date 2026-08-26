//
//  MercyRequestService.swift
//  PPTAMinimal
//
//  Files a trainee's "give me more time" request raised from the shield's secondary button.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Bridges the shield action extension's App Group marker into Firestore.
///
/// The extension can't reach the network, so it records a marker and hands off via a local
/// notification; this runs on the app's next foreground and files the real request — the same
/// consume-on-foreground shape as `UserSettingsManager.applyPendingStatusIfNeeded()`.
enum MercyRequestService {
    /// Requests older than this are dropped rather than filed: a trainee who ignored the
    /// handoff notification yesterday doesn't want it sent when they open the app today.
    private static let maxAge: TimeInterval = 60 * 60

    // MARK: - Coach side (vestigial)
    //
    // The snooze request now lives as `UserSettings.isRequestingSnooze` (set/cleared by the
    // `statusUpdate` server, read live by coaches) — see NOTIFICATIONS/mercy plan. The
    // `mercyRequests` collection is no longer written, so these two query an empty collection
    // and are effectively no-ops. Kept only so the dead-code `StatusCenterView` still compiles.

    /// Whether `traineeId` has an open request addressed to `coachId`.
    static func hasPendingRequest(traineeId: String, coachId: String) async -> Bool {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("mercyRequests")
                .whereField("traineeId", isEqualTo: traineeId)
                .whereField("coachIds", arrayContains: coachId)
                .whereField("status", isEqualTo: "pending")
                .limit(to: 1)
                .getDocuments()
            return !snapshot.documents.isEmpty
        } catch {
            print("MercyRequestService: pending lookup failed: \(error)")
            return false
        }
    }

    /// Closes out a trainee's open requests once the coach has acted on them.
    static func resolveRequests(traineeId: String, coachId: String) async {
        do {
            let snapshot = try await Firestore.firestore()
                .collection("mercyRequests")
                .whereField("traineeId", isEqualTo: traineeId)
                .whereField("coachIds", arrayContains: coachId)
                .whereField("status", isEqualTo: "pending")
                .getDocuments()

            for document in snapshot.documents {
                try await document.reference.updateData([
                    "status": "resolved",
                    "resolvedBy": coachId,
                    "resolvedAt": Timestamp(date: Date())
                ])
            }
        } catch {
            print("MercyRequestService: failed to resolve requests: \(error)")
        }
    }

    // MARK: - Trainee side

    @MainActor
    static func filePendingRequestIfNeeded() async {
        guard let requestedAt = MercyRequestStore.consume() else { return }

        guard Date().timeIntervalSince(requestedAt) <= maxAge else {
            print("MercyRequestService: dropping stale request from \(requestedAt).")
            return
        }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let settings = UserSettingsManager.shared.userSettings
        let coachIds = settings.coachIds
        guard !coachIds.isEmpty else {
            print("MercyRequestService: no coaches to ask.")
            return
        }

        // The signed push to `statusUpdate` is the request: the server raises
        // `UserSettings.isRequestingSnooze` on the trainee's doc, which the trainee's coaches read
        // live (and which clears itself on any non-cutOff status). No separate Firestore record
        // needed — the flag on their settings is the durable, self-clearing source of truth.
        DeviceActivityManager.shared.sendMercyRequest(uid: uid)

        NotificationManager.shared.sendNotification(
            title: "Request sent! 🙏",
            body: coachIds.count == 1
                ? "Your coach has been asked for more time."
                : "Your coaches have been asked for more time."
        )
    }
}
