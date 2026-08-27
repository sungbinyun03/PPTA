//
//  MercyRequestService.swift
//  PPTAMinimal
//
//  Vestigial coach-side helpers for the old broadcast mercy-request flow.
//

import Foundation
import FirebaseFirestore

/// Per-coach snooze requests now live as `UserSettings.snoozeRequestedCoachIds` (a trainee asks one
/// coach at a time from that coach's profile — see `FriendProfileViewModel.requestSnooze`). The
/// `statusUpdate` server arrayUnions/empties that list and coaches read it live. The old
/// `mercyRequests` collection is no longer written, so the two helpers below query an empty
/// collection and are effectively no-ops — kept only so the dead-code `StatusCenterView` compiles.
enum MercyRequestService {

    // MARK: - Coach side (vestigial)

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
}
