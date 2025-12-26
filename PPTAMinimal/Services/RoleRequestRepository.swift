//
//  RoleRequestRepository.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseFirestore

final class RoleRequestRepository {
    private let db = Firestore.firestore()
    private let http = CloudRunHTTPClient(baseURL: CloudRunConfig.roleRequestsBaseURL)
    private let collection = "roleRequests"

    // MARK: - Reads (Firestore)

    func fetchIncomingPending(for uid: String) async throws -> [RoleRequest] {
        let snap = try await db.collection(collection)
            .whereField("targetId", isEqualTo: uid)
            .whereField("status", isEqualTo: RoleRequestStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: RoleRequest.self) }
    }

    func fetchOutgoingPending(for uid: String) async throws -> [RoleRequest] {
        let snap = try await db.collection(collection)
            .whereField("requesterId", isEqualTo: uid)
            .whereField("status", isEqualTo: RoleRequestStatus.pending.rawValue)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return try snap.documents.compactMap { try $0.data(as: RoleRequest.self) }
    }

    // MARK: - Writes (Cloud Functions)

    func createRoleRequest(targetId: String, role: RoleRequestRole) async throws -> String {
        struct Resp: Decodable { let id: String }
        let resp: Resp = try await http.postJSON("", body: [
            "action": "createRoleRequest",
            "targetId": targetId,
            "role": role.rawValue
        ])
        return resp.id
    }

    func accept(id: String) async throws {
        try await http.postJSON("", body: ["action": "acceptRoleRequest", "id": id])
    }

    func decline(id: String) async throws {
        try await http.postJSON("", body: ["action": "declineRoleRequest", "id": id])
    }

    func cancel(id: String) async throws {
        try await http.postJSON("", body: ["action": "cancelRoleRequest", "id": id])
    }

    /// Removes an already-accepted relationship.
    /// - Parameters:
    ///   - otherId: the other user uid
    ///   - role: the current user's role relative to otherId:
    ///     - `.coach` means current user coaches otherId (otherId is current user's trainee)
    ///     - `.trainee` means current user is trainee of otherId (otherId is current user's coach)
    func removeRelationship(otherId: String, role: RoleRequestRole) async throws {
        try await http.postJSON("", body: [
            "action": "removeRoleRelationship",
            "otherId": otherId,
            "role": role.rawValue
        ])
    }
}



