//
//  RoleRequest.swift
//  PPTAMinimal
//
//  Created by Assistant on 12/21/25.
//

import Foundation
import FirebaseFirestore

enum RoleRequestRole: String, Codable {
    /// Requester wants to be the coach of the target.
    case coach
    /// Requester wants to be the trainee of the target.
    case trainee
}

enum RoleRequestStatus: String, Codable {
    case pending
    case accepted
    case declined
    case cancelled
}

struct RoleRequest: Identifiable, Codable {
    @DocumentID var id: String?
    let requesterId: String
    let targetId: String
    let role: RoleRequestRole
    let status: RoleRequestStatus
    let createdAt: Date?
    let resolvedAt: Date?
}



