//
//  TraineeCoachCircleView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCircleView: View {
    private let status: TraineeStatus
    private let name: String
    private let profilePicUrl: String?
    
    init(status: TraineeStatus = .allClear, name: String, profilePicUrl: String? = nil) {
        self.status = status
        self.name = name
        self.profilePicUrl = profilePicUrl
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Group {
                if let profilePicUrl, let url = URL(string: profilePicUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            Image("google-icon").resizable().scaledToFill()
                        }
                    }
                } else {
            Image("google-icon")
                .resizable()
                .scaledToFill()
                }
            }
                .frame(width: 75, height: 75)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .inset(by: -5)
                        .stroke(status.ringColor ?? .clear, lineWidth: 15)
                    Circle()
                        .stroke((status == .noStatus) ? .clear : .white, lineWidth: 5)
                }
            Text(name)
                .font(.custom("SatoshiVariable-Bold_Light", size: 15)) // TODO: Update text font; also, how do you get or find the different available fonts???
        }
    }
}

#Preview {
    TraineeCircleView(status: TraineeStatus.attentionNeeded, name: "Sungbin")
}
