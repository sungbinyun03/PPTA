//
//  User.swift
//  PPTAMinimal
//
//  Created by Jovy Zhou on 1/20/25.
//

import Foundation

struct User: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let email: String
    var phoneNumber: String?
    var fcmToken: String?
    
    var intiials: String {
        let formatter = PersonNameComponentsFormatter()
        if let components = formatter.personNameComponents(from: name) {
            formatter.style = .abbreviated
            return formatter.string(from: components)
        }
        
        return ""
    }
    
    init(id: String, name: String, email: String, phoneNumber: String? = nil, fcmToken: String? = nil) {
            self.id = id
            self.name = name
            self.email = email
            self.phoneNumber = phoneNumber
            self.fcmToken = fcmToken
        }
}

extension User {
    static var MOCK_USER = User(id: NSUUID().uuidString, name: "Jovy Zhou", email: "test@gmail.com")
}
