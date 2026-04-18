//
//  TabNavigator.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 3/1/25.
//

import SwiftUI

struct TabNavigator: View {
    @State private var selected = 0
    @StateObject private var roleInbox = RoleRequestsInboxViewModel()
    @ObservedObject private var notifications = NotificationManager.shared
    
    private let previewMode: Bool
    
    init(previewMode: Bool = false) {
        self.previewMode = previewMode
        
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        appearance.shadowColor = UIColor.black.withAlphaComponent(0.08)

        let inactive = UIColor.systemGray2
        let active = UIColor(named: "primaryColor") ?? UIColor.systemGreen

        appearance.stackedLayoutAppearance.normal.iconColor = inactive
        appearance.stackedLayoutAppearance.selected.iconColor = active
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: inactive,
            .font: UIFont.systemFont(ofSize: 10, weight: .medium)
        ]
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: active,
            .font: UIFont.systemFont(ofSize: 10, weight: .semibold)
        ]

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
            FriendsView()
                .tabItem {
                    Image(systemName: "figure.2")
                    Text("Friends")
                }
                .tag(1)
        }
        .environmentObject(roleInbox)
        .overlay(alignment: .top) {
            if let banner = notifications.inAppBanner {
                InAppBannerView(title: banner.title, message: banner.body) {
                    notifications.inAppBanner = nil
                }
                .padding(.top, 8)
            }
        }
        .task {
            await roleInbox.refreshOnce()
            roleInbox.startListening()
        }
        .onDisappear {
            roleInbox.stopListening()
        }
    }
}

#Preview("TabNavigator") {
    let auth = AuthViewModel()
    auth.currentUser = User(id: "preview-user", name: "Preview Name", email: "preview@example.com")
    
    return TabNavigator(previewMode: true)
        .environmentObject(auth)
}
