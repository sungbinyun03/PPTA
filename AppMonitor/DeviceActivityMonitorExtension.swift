//
//  DeviceActivityMonitorExtension.swift
//  AppMonitor
//
//  Created by Sungbin Yun on 1/12/25.
//

import DeviceActivity
import ManagedSettings
import Foundation

// Optionally override any of the functions below.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        
        NotificationManager.shared.sendNotification(
               title: "Usage Window Started",
               body: "You’ll soon be monitored for daily limits!"
           )
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
            super.eventDidReachThreshold(event, activity: activity)
        
            let settings = LocalSettingsStore.load()
            store.shield.applications = settings.applications.applicationTokens
            NotificationManager.shared.sendNotification(
               title: "Usage Window Ended",
               body: String(settings.applications.applicationTokens.count)
            )
        
            store.shield.applications = UserSettingsManager.shared.userSettings.applications.applicationTokens
            
            // If the user is actively tracking, flag a breach so the main app
            // can update Firestore (status + streak) next time it becomes active.
            if settings.isTracking {
                LocalSettingsStore.savePendingStatus(.cutOff, resetStartDate: Date())
            }
//            
//            // Un-shield after 2 hours
//            let unlockTime: TimeInterval = 2 * 60
//            DispatchQueue.main.asyncAfter(deadline: .now() + unlockTime) { [weak self] in
//                self?.store.shield.applications = nil
//                print("Removed shield after 2 min.")
//                        }
//                    let appBundleID = event.rawValue.replacingOccurrences(of: "limit_", with: "")
//
//        
            let appBundleID = event.rawValue.replacingOccurrences(of: "limit_", with: "")
            let appName = getAppName(for: appBundleID)
            let currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? "Your friend"
            let notificationBody = "\(currentUserName) has reached their time limit for \(appName)!"
            
//            NotificationManager.shared.sendPushNotification(
//                title: "Time is Up!",
//                body: notificationBody
//            )
        }
    
    override func intervalWillStartWarning(for activity: DeviceActivityName) {
        super.intervalWillStartWarning(for: activity)
        
        // Handle the warning before the interval starts.
    }
    
    override func intervalWillEndWarning(for activity: DeviceActivityName) {
        super.intervalWillEndWarning(for: activity)
        
        // Handle the warning before the interval ends.
    }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
            super.eventWillReachThresholdWarning(event, activity: activity)

            let appBundleID = event.rawValue.replacingOccurrences(of: "limit_", with: "")

            let appName = getAppName(for: appBundleID)
            let currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? ""

            let notificationBody = "\(currentUserName) is about to reach their time limit for \(appName)!"
            
            // Mark that the user is approaching their limit so coaches can see
            // this reflected as `.attentionNeeded` after the app syncs.
            let settings = LocalSettingsStore.load()
            if settings.isTracking {
                LocalSettingsStore.savePendingStatus(.attentionNeeded, resetStartDate: nil)
            }
            NotificationManager.shared.sendPushNotification(
                    title: "Time Almost Up!",
                    body: notificationBody
                )
        }
        

    
    private func getAppName(for bundleID: String) -> String {
            let appMappings: [String: String] = [
                "com.apple.youtube": "YouTube",
                "com.apple.tiktok": "TikTok",
                "com.apple.instagram": "Instagram"
            ]
            return appMappings[bundleID] ?? "an app"
        }
}
