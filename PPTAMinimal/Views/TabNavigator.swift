//
//  TabNavigator.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI

struct TabNavigator: View {
    @State private var selected = 0
    
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        
        // Initialize tabbar appearance template
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "secondaryColor")
        appearance.stackedLayoutAppearance.normal.iconColor = .white
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(named: "primaryColor")
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(named: "primaryColor")
        ]

        // Assign the tabbar appearance template
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        TabView(selection: $selected) {
            HomeView(previewMode: previewMode)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            StatusCenterView()
                .tabItem {
                    Image(systemName: "chart.bar.xaxis.ascending")
                    Text("Status")
                }
                .tag(1)
            FriendsView()
                .tabItem {
                    Image(systemName: "figure.2")
                    Text("Friends")
                }
                .tag(2)
        }
    }
}

#Preview("TabNavigator") {
    let auth = AuthViewModel()
    auth.currentUser = User(id: "preview-user", name: "Preview Name", email: "preview@example.com")
    
    return TabNavigator(previewMode: true)
        .environmentObject(auth)
}
