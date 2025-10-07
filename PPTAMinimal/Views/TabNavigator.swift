//
//  TabNavigator.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI

struct TabNavigator: View {
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
    }
    
    var body: some View {
        TabView {
            HomeView(previewMode: previewMode)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
        }
        .background(Color.white)
        .edgesIgnoringSafeArea(.all)
    }
}

#Preview("TabNavigator") {
    let auth = AuthViewModel()
    auth.currentUser = User(id: "preview-user", name: "Preview Name", email: "preview@example.com")
    
    return TabNavigator(previewMode: true)
        .environmentObject(auth)
}
