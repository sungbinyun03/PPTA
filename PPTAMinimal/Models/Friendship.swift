//
//  Friendship.swift
//  PPTAMinimal
//
//  Created by Assistant on 11/11/25.
//

import Foundation

enum FriendshipStatus: String, Codable {
    case pending
    case accepted
    case declined
}

struct Friendship: Identifiable, Codable {
    var id: String
    var requesterId: String
    var requesteeId: String
    var status: FriendshipStatus
    var createdAt: Date
}


