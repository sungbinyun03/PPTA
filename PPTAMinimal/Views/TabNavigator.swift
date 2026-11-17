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
    @StateObject private var friendsBadgeVm = FriendsViewModel()
    @StateObject private var statusVm = StatusCenterViewModel()
    @ObservedObject private var notifications = NotificationManager.shared
    /// The badge lists have loaded once; until then the icon keeps what the last push set, so a
    /// half-loaded count can't clear it.
    @State private var badgeListsLoaded = false
    /// Launch reminder (`PermissionsView`): once per app launch while Screen Time or full
    /// notifications are missing. "Not now" closes it until the next launch.
    @State private var showPermissionsReminder = false
    @ObservedObject private var permissions = PermissionsMonitor.shared
    
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
    
    private func loadPeopleForLaunch() async {
        await statusVm.refresh()
        await InitialsProfilePicView.prefetch((statusVm.trainees + statusVm.coaches).map(\.profileImageURL))
        LaunchGate.shared.markPeopleLoaded()
    }

    var body: some View {
        TabView(selection: $selected) {
            HomeView(previewMode: previewMode)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .badge(statusVm.trainees.filter { $0.traineeStatus == .attentionNeeded }.count)
                .tag(0)
            FriendsView()
                .tabItem {
                    if friendsBadgeVm.friends.isEmpty {
                        Image(uiImage: (UIImage(systemName: "exclamationmark.circle.fill") ?? UIImage())
                            .withTintColor(.orange, renderingMode: .alwaysOriginal))
                    } else {
                        Image(systemName: "figure.2")
                    }
                    Text("Friends")
                }
                .badge(friendsBadgeVm.incomingRequests.count + roleInbox.incoming.count)
                .tag(1)
        }
        .environmentObject(roleInbox)
        .environmentObject(statusVm)
        .overlay(alignment: .top) {
            if let banner = notifications.inAppBanner {
                InAppBannerView(title: banner.title, message: banner.body) {
                    notifications.inAppBanner = nil
                }
                .padding(.top, 8)
            }
        }
        .onChange(of: appBadgeCount) { _, count in
            if badgeListsLoaded { AppBadge.set(count) }
        }
        .onReceive(notifications.$coachesPopoverRequestedAt) { requestedAt in
            // The popover lives on Home.
            if requestedAt != nil { selected = 0 }
        }
        .task {
            // Started first and run alongside the badge loads: the cold-launch facade waits on it
            // (coach/trainee lists + their avatars), so it shouldn't queue behind them.
            async let people: Void = loadPeopleForLaunch()
            await roleInbox.refreshOnce()
            roleInbox.startListening()
            await friendsBadgeVm.refresh()
            friendsBadgeVm.startListening()
            await people
            badgeListsLoaded = true
            AppBadge.set(appBadgeCount)
            // After the launch facade (the people load above), so the reminder isn't hidden under it.
            await showPermissionsReminderIfNeeded()
        }
        .fullScreenCover(isPresented: $showPermissionsReminder) {
            PermissionsView(coordinator: OnboardingCoordinator(),
                            mode: .reminder(onClose: { showPermissionsReminder = false }))
        }
        .onDisappear {
            roleInbox.stopListening()
            friendsBadgeVm.stopListening()
        }
    }
}

extension TabNavigator {
    /// Once per launch: anything missing opens the permissions screen over the app.
    private func showPermissionsReminderIfNeeded() async {
        guard !previewMode, !permissions.checkedThisLaunch else { return }
        permissions.checkedThisLaunch = true
        await permissions.refresh()
        if !permissions.gap.isEmpty { showPermissionsReminder = true }
    }

    /// The app icon's red count (`AppBadge`), from the same live lists as the tab badges.
    private var appBadgeCount: Int {
        AppBadge.count(trainees: statusVm.trainees,
                       incomingFriendRequests: friendsBadgeVm.incomingRequests.count,
                       incomingRoleRequests: roleInbox.incoming.count)
    }
}

#Preview("TabNavigator") {
    let auth = AuthViewModel()
    auth.currentUser = User(id: "preview-user", name: "Preview Name", email: "preview@example.com")
    
    return TabNavigator(previewMode: true)
        .environmentObject(auth)
}
