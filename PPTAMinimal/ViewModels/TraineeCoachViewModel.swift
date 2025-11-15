//
//  TraineeCoachViewModel.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import Foundation

// TODO: Need to fetch trainees and coaches from Firestore

class TraineeCoachViewModel: ObservableObject {
    @Published var users: [PeerCoach] = [
        .init(givenName: "Omar", familyName: "Thamri", phoneNumber: "123456789", fcmToken: nil),
        .init(givenName: "Dwight", familyName: "Schrute", phoneNumber: "123456789", fcmToken: nil),
        .init(givenName: "Pam", familyName: "Beesley", phoneNumber: "123456789", fcmToken: nil),
        .init(givenName: "Jim", familyName: "Halpert", phoneNumber: "123456789", fcmToken: nil),
        .init(givenName: "Natsha", familyName: "Romanoff", phoneNumber: "123456789", fcmToken: nil)
    ]
    
    @Published var trainees: [PeerCoach] = []
    @Published var coaches: [PeerCoach] = []
    
    init() {
        setupTraineesCoaches()
    }
    
    private func setupTraineesCoaches() {
        trainees = users.enumerated()
                  .filter { [0, 1, 3, 4, 2].contains($0.offset) }
                  .map(\.element)
        
        coaches = users.enumerated()
                  .filter { [2, 4].contains($0.offset) }
                  .map(\.element)
    }
}
