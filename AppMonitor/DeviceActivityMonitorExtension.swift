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
            NotificationManager.shared.sendNotification(
               title: "Usage Window Ended",
               body: "TIME's UP"
            )
            store.shield.applications = UserSettingsManager.shared.userSettings.applications.applicationTokens
            
            // Un-shield after 2 hours
            let unlockTime: TimeInterval = 2 * 60
            DispatchQueue.main.asyncAfter(deadline: .now() + unlockTime) { [weak self] in
                self?.store.shield.applications = nil
                print("Removed shield after 2 min.")
                        }
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
