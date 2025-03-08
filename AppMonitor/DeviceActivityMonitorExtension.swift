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
        // Handle the start of the interval.
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        super.eventDidReachThreshold(event, activity: activity)        
        let currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? "Your friend"
        let notificationBody = "\(currentUserName) has reached their daily time limit!"

        NotificationManager.shared.sendPushNotification(
            title: "Time is Up!",
            body: notificationBody
        )
    
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
//        NotificationManager.shared.sendNotification(
//               title: "Usage Window About to End",
//               body: "Your time interval will end soon!"
//           )
        
        UserSettingsManager.shared.loadSettings { userSettings in
            let currentUserName = UserDefaults.standard.string(forKey: "currentUserName") ?? ""

            let peerCoaches = userSettings.peerCoaches
            let notificationBody = "Your friend \(currentUserName) has reached the time limit!"

            NotificationManager.shared.sendPushNotification(
                title: "Time is Up!",
                body: notificationBody
            )
            
        }
        // Handle the warning before the event reaches its threshold.
    }
}
