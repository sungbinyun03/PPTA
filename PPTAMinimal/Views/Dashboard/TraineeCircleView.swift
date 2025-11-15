//
//  TraineeCoachCircleView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 29/9/25.
//

import SwiftUI

struct TraineeCircleView: View {
    @StateObject private var viewModel: TraineeCoachViewModel
    private var index: Int
    private let status: TraineeStatus
    private let name: String
    
    init(viewModel: TraineeCoachViewModel, index: Int, status: TraineeStatus = .allClear, name: String) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.index = index
        self.status = status
        self.name = name
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 20) {
            Image("google-icon")
                .resizable()
                .scaledToFill()
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
    TraineeCircleView(viewModel: TraineeCoachViewModel(), index: 0, status: TraineeStatus.attentionNeeded, name: "Sungbin")
}
