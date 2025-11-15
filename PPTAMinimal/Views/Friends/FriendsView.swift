//
//  FriendsView.swift
//  PPTAMinimal
//
//  Created by Damien Koh on 6/11/25.
//

import SwiftUI

struct FriendsView: View {
    
    var body: some View {
        NavigationStack {
            ScrollView{
                VStack(spacing: 5) {
                    Text("Hello World!")
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    FriendsView()
}
