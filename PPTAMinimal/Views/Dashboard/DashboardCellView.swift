//
//  DashboardCellView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 9/9/25.
//

import SwiftUI

struct DashboardCellView: View {
    private var cellTitle: String
    private var cellContent: String
    init(cellTitle: String, cellContent: String) {
        self.cellTitle = cellTitle
        self.cellContent = cellContent
    }
    var body: some View {
        Button(action: {
            
        }, label: {
            VStack(spacing: 10) {
                Text("\(cellTitle)")
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(cellContent)")
                    .font(.system(size: 32, weight: .bold))
            }
        })
        .frame(width: 160, height: 110)
        .background(Color(red: 0.4392, green: 0.4784, blue: 0.3843))
        .foregroundColor(.white)
        .cornerRadius(15)
    }
}

#Preview {
    DashboardCellView(cellTitle: "Peers you are watching", cellContent: "14h 45m")
}
