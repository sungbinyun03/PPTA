//
//  DeviceActivityMonitorExtension.swift
//  AppMonitor
//
//  Created by Sungbin Yun on 1/12/25.
//

import DeviceActivity
import ManagedSettings
import Foundation
import CryptoKit

// Optionally override any of the functions below.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
    
    let store = ManagedSettingsStore()
    
    /// Must match the backend `UNLOCK_SECRET` exactly (string bytes, not hex-decoded bytes),
    /// to stay consistent with the existing `UnlockService` implementation.
    private static let sharedSecret = "a282b15352ee133e244ee5be0a2e3b9fa11b5503b6f22b1a92b57806a412122e"
    
    /// TODO: Set this to the deployed `statusUpdate` Cloud Run URL.
    /// This should be a separate function/service from unlockApp (recommended).
    private static let statusUpdateURL = URL(string: "https://statusupdate-538124351649.us-central1.run.app")!

    override func intervalDidStart(for activity: DeviceActivityName) {
        super.intervalDidStart(for: activity)
        let settings = LocalSettingsStore.load()
        
        // Reset to allClear at the start of the window (near-real-time coach visibility).
        if settings.isTracking {
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .allClear)
        }
    }
    
    override func intervalDidEnd(for activity: DeviceActivityName) {
        super.intervalDidEnd(for: activity)
        store.shield.applications = nil
        
        let settings = LocalSettingsStore.load()
        if settings.isTracking {
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .allClear)
        }
    }
    
    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
            super.eventDidReachThreshold(event, activity: activity)
        
            let settings = LocalSettingsStore.load()
            guard settings.isTracking else { return }
            
            // Minimal: one threshold event => treat it as "daily limit reached".
            // Mode behavior:
            // - Chill: no shielding (just status updates)
            // - Coach/Hard: shield selected apps
            switch settings.selectedMode {
            case "Chill":
                break
            case "Coach", "Hard":
                store.shield.applications = settings.applications.applicationTokens
            default:
                // Fail safe to Coach-like behavior.
                store.shield.applications = settings.applications.applicationTokens
            }
            
            // Persist locally for the app to pick up (streak reset), AND notify backend immediately.
            LocalSettingsStore.savePendingStatus(.cutOff, resetStartDate: Date())
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .cutOff)
        }
    
    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
            super.eventWillReachThresholdWarning(event, activity: activity)
            let settings = LocalSettingsStore.load()
            guard settings.isTracking else { return }
            
            // Mark approaching limit (local + backend).
            LocalSettingsStore.savePendingStatus(.attentionNeeded, resetStartDate: nil)
            sendStatusUpdate(uid: LocalSettingsStore.loadCurrentUserId(), status: .attentionNeeded)
        }
    
    // MARK: - Backend status update
    
    /// Sends a signed status update to Cloud Run so coaches can see changes almost immediately.
    /// \n- Important: This function must be resilient; failures should not block shielding.
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
        
        // Fire-and-forget. Do not block DeviceActivity callbacks.
        let task = URLSession.shared.dataTask(with: req) { _, _, _ in }
        task.resume()
    }
}
