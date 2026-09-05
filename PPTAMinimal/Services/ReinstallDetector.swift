//
//  ReinstallDetector.swift
//  PPTAMinimal
//
//  Detects when the app has been deleted and reinstalled on this device, and — if the same user
//  comes back — reports it to their coaches. An accountability deterrent: a trainee who deletes PPTA
//  to escape a lock and later reinstalls (to keep their streak / keep using the app) is surfaced to
//  the people holding them accountable.
//
//  iOS provides no uninstall event, so this can't be observed at delete time. The trick: the
//  **Keychain survives an uninstall**, but the app sandbox (UserDefaults / app group) is wiped. So
//  "a Keychain marker exists but the UserDefaults mirror is gone" uniquely means the app was removed
//  and reinstalled. (The app already depends on this behavior indirectly — Firebase Auth persists its
//  session in the Keychain, which is why a reinstall can come back already signed in.)
//

import Foundation
import Security

enum ReinstallDetector {
    // Keychain: per-device, survives uninstall. Holds the last install's uid.
    private static let keychainService = "com.sungbinyun.PPTA.install"
    private static let keychainAccount = "installMarkerUID"
    // UserDefaults mirror: wiped on uninstall. Its absence (with a Keychain marker present) = reinstall.
    private static let mirrorKey = "ppta.installMirrorPresent"

    /// Evaluate at most once per launch — `AuthViewModel.fetchUser()` runs several times per session.
    private static var evaluatedThisLaunch = false

    /// Call once an authenticated `uid` is known. If this launch is a reinstall by the *same* user,
    /// notifies their coaches, then normalizes the markers so later launches read as normal.
    static func handleAuthenticated(uid: String) {
        guard !evaluatedThisLaunch else { return }
        evaluatedThisLaunch = true

        let priorUID = keychainUID()                                    // survives uninstall
        let mirrorPresent = UserDefaults.standard.bool(forKey: mirrorKey) // wiped on uninstall

        // Reinstall == the Keychain remembers a prior install but the sandbox mirror is gone.
        if let priorUID, !mirrorPresent {
            // Only report when the SAME person returns. A different account on this device is that
            // person's first install here, not a reinstall to flag.
            if priorUID == uid {
                DeviceActivityManager.shared.sendReinstallNotice(uid: uid)
            }
        }

        // Normalize for next launch.
        setKeychainUID(uid)
        UserDefaults.standard.set(true, forKey: mirrorKey)
    }

    // MARK: - Keychain

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
    }

    private static func keychainUID() -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func setKeychainUID(_ uid: String) {
        // Delete-then-add keeps this simple and lets us set the accessibility attribute cleanly.
        SecItemDelete(baseQuery() as CFDictionary)
        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = Data(uid.utf8)
        // Readable after first unlock (fetchUser runs post-unlock); ThisDeviceOnly so it never syncs
        // via iCloud Keychain — reinstall detection is intentionally per-device.
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }
}
