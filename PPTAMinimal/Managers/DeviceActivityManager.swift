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
import CryptoKit

class DeviceActivityManager {
    static let shared = DeviceActivityManager()
    private init() {}
    let deviceActivityCenter = DeviceActivityCenter()
    private let store = ManagedSettingsStore()
    
    /// Must match backend `UNLOCK_SECRET` exactly (string bytes).
    private static let sharedSecret = "a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"
    
    /// TODO: Set this to the deployed `statusUpdate` Cloud Run URL.
    private static let statusUpdateURL = URL(string: "https://statusupdate-538124351649.us-central1.run.app")!
    
    func startDeviceActivityMonitoring(
        appTokens: FamilyActivitySelection,
        hour: Int,
        minute: Int,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        let thresholdComponents = DateComponents(hour: hour, minute: minute)
        
        // Monitor from midnight to 23:59, repeating daily
        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59),
            repeats: true,
            warningTime: DateComponents(minute: 5) // optional
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
    
    func stopMonitoring() {
        deviceActivityCenter.stopMonitoring()
        print("Stopped all device activity monitoring.")
    }
    
    @MainActor
    func handleRemoteUnlock(from coach: String) {
        let settings = LocalSettingsStore.load()
        if settings.selectedMode == "Hard" {
            NotificationManager.shared.sendNotification(
                title: "Unlock denied",
                body: "Hardcore mode is enabled."
            )
            return
        }
        
        store.shield.applications = nil

        NotificationManager.shared.sendNotification(
            title: "Unlocked by \(coach)",
            body: "Be Mindful of Your Screentime!"
        )
        
        // Best-effort: notify backend that user is back to allClear.
        if settings.isTracking {
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .allClear)
        }
    }
    
    private func sendStatusUpdate(uid: String?, status: TraineeStatus) {
        guard let uid, !uid.isEmpty else { return }

        let ts = Int(Date().timeIntervalSince1970)
        let msg = "\(uid)|\(status.rawValue)|\(ts)"
        let key = SymmetricKey(data: Data(Self.sharedSecret.utf8))
        let sig = HMAC<SHA256>
            .authenticationCode(for: msg.data(using: .utf8)!, using: key)
            .map { String(format: "%02x", $0) }
            .joined()

        var req = URLRequest(url: Self.statusUpdateURL)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "uid": uid,
            "status": status.rawValue,
            "ts": ts,
            "sig": sig
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
    }
}
