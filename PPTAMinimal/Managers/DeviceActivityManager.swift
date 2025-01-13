//
//  DeviceActivityManager.swift
//  PPTA
//
//  Created by Sungbin Yun on 12/30/24.
//

import Foundation
import ManagedSettings
import DeviceActivity
import FamilyControls

class DeviceActivityManager {
    static let shared = DeviceActivityManager()
    private init() {}
    let deviceActivityCenter = DeviceActivityCenter()
    
    // MARK: Start Monitoring
    func startDeviceActivityMonitoring(
        appTokens: FamilyActivitySelection,
        hour: Int,
        minute: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let thresholdComponents = DateComponents(hour: hour, minute: minute)
        
        // Full-day schedule
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5)
        )
        
        let event = DeviceActivityEvent(
            applications: appTokens.applicationTokens,
            threshold: thresholdComponents
        )
        
        let activityName = DeviceActivityName("AppUsageMonitoring")
        let eventName = DeviceActivityEvent.Name("timeLimitReached")
        
        do {
            try deviceActivityCenter.startMonitoring(
                activityName,
                during: schedule,
                events: [eventName: event]
            )
            print("Monitoring started. Activity: \(activityName.rawValue)")
            print("Schedule: \(schedule)")
            print("Event: \(eventName) => threshold \(thresholdComponents)")
            print("Apps: \(appTokens.applicationTokens)")
            
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }
    
    // MARK: Stop Monitoring
    func handleStopDeviceActivityMonitoring() {
        deviceActivityCenter.stopMonitoring()
        print("Stopped all device activity monitoring.")
    }
}
