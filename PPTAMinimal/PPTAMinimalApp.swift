//
//  PPTAMinimalApp.swift
//  PPTAMinimal
//
//  Created by Sungbin Yun on 1/12/25.
//

import SwiftUI
import Firebase
import GoogleSignIn
import FirebaseAuth
import FirebaseMessaging


class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
          FirebaseApp.configure()
          // Register for APNs unconditionally — required for Firebase Phone Auth silent
          // push verification regardless of whether the user grants notification permission.
          UIApplication.shared.registerForRemoteNotifications()
          UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
          UNUserNotificationCenter.current().delegate = self
          Messaging.messaging().delegate = self
          return true
      }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        
        if Auth.auth().canHandle(url) {
            return true
        }
        
        if GIDSignIn.sharedInstance.handle(url) {
            return true
        }
        return false
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data){
        #if DEBUG
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        Messaging.messaging().apnsToken = deviceToken
        #else
        Auth.auth().setAPNSToken(deviceToken, type: .prod)
        Messaging.messaging().apnsToken = deviceToken
        #endif
        print("🟢 APNs token registered")
        print("@@ TOKEN RECEIVED: \(deviceToken.map { String(format: "%02x", $0)}.joined())")
    }
    
    /// Whether the push has an APNs alert, i.e. iOS shows the banner itself and the handler must
    /// not post a local one on top.
    private static func carriesAlert(_ notification: [AnyHashable: Any]) -> Bool {
        (notification["aps"] as? [String: Any])?["alert"] != nil
    }

    /// Runs `work`, then calls `completionHandler(.newData)`. The call is what tells iOS it may
    /// suspend the app, so it has to come after the handler's Firestore and `statusUpdate` writes,
    /// or they can be left in flight. A background task plus a cap keep a stalled network from
    /// burning the wake budget (or getting the app killed) — at the cap we finish regardless.
    private static func finishWork(
        then completionHandler: @escaping (UIBackgroundFetchResult) -> Void,
        _ work: @escaping @MainActor () async -> Void
    ) {
        let app = UIApplication.shared
        var bgTask = UIBackgroundTaskIdentifier.invalid
        bgTask = app.beginBackgroundTask(withName: "remoteLockWork") {
            app.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        // Whichever of `work` and the cap finishes first completes. Unstructured tasks rather
        // than a task group: a group would still wait on `work` after the cap fired.
        var finished = false
        let finish = { @MainActor in
            guard !finished else { return }
            finished = true
            completionHandler(.newData)
            if bgTask != .invalid {
                app.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        Task { @MainActor in
            await work()
            finish()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 20_000_000_000)
            finish()
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
        print("@@@ Received Remote Notification: \(notification)")
        if Auth.auth().canHandleNotification(notification){
            completionHandler(.noData)
            return
        }
        if
            let type = notification["type"] as? String, type == "unlock",
            notification["by"] as? String != nil
        {
            // Prefer resolved display name; fall back to UID if server didn't include it.
            let coachName = (notification["byName"] as? String)?.firstNameOnly ?? "Your coach"
            print("!!!! Unlock notification received. Coach: \(coachName)")
            let pushShowsBanner = Self.carriesAlert(notification)
            Self.finishWork(then: completionHandler) {
                await LockReconciler.shared.applyPush(notification, pushShowsBanner: pushShowsBanner)
            }
            return
        }

        if
            let type = notification["type"] as? String, type == "lock",
            notification["by"] as? String != nil
        {
            let coachName = (notification["byName"] as? String)?.firstNameOnly ?? "Your coach"
            print("!!!! Lock notification received. Coach: \(coachName)")
            let pushShowsBanner = Self.carriesAlert(notification)
            Self.finishWork(then: completionHandler) {
                await LockReconciler.shared.applyPush(notification, pushShowsBanner: pushShowsBanner)
            }
            return
        }
        
        if
            let type = notification["type"] as? String, type == "traineeStatus",
            let status = notification["status"] as? String
        {
            // First names only — the server sends full display names, but "Damien Koh's lock has
            // been snoozed!" runs long in a title.
            let traineeName = (notification["traineeName"] as? String)?.firstNameOnly ?? "Your trainee"
            let cause = notification["cause"] as? String
            let byUID = notification["by"] as? String
            let byName = (notification["byName"] as? String)?.firstNameOnly ?? "A coach"
            // The fan-out reaches every coach, including the one who acted. Show them "You…".
            let actedBySelf = byUID != nil && byUID == Auth.auth().currentUser?.uid

            // Title = "{trainee} <short event>"; body elaborates (who/why). `nil` → no notification
            // (allClear is the silent daily reset — the coach's Status Center refreshes from Firestore).
            let content: (title: String, body: String)? = {
                switch status {
                case TraineeStatus.attentionNeeded.rawValue:
                    // Standard-only: hitting the limit in Hardcore goes straight to cutOff.
                    return ("\(traineeName) hit their time limit! 👀", "Go ahead and cut them off!")
                case TraineeStatus.cutOff.rawValue:
                    switch cause {
                    case LockCause.hardcoreLimit.rawValue:
                        return ("\(traineeName) has been locked! 🔒", "They hit their limit — their apps locked automatically.")
                    case LockCause.coach.rawValue:
                        return ("\(traineeName) has been locked! 🔒",
                                actedBySelf ? "You cut off their apps." : "\(byName) cut off their apps.")
                    case LockCause.snoozeEnded.rawValue:
                        return ("\(traineeName) has been locked! 🔒", "Their snooze ran out — they're locked again.")
                    default:
                        return ("\(traineeName) has been locked! 🔒", "Their apps are now locked.")
                    }
                case TraineeStatus.snoozedLock.rawValue:
                    return ("\(traineeName)'s lock has been snoozed! ⏳",
                            actedBySelf ? "You gave them 10 more minutes." : "\(byName) gave them 10 more minutes.")
                case TraineeStatus.allClear.rawValue:
                    return nil
                default:
                    return ("Accountability update", "\(traineeName) has a status update.")
                }
            }()
            // A server alert is shown by iOS itself (even when the app is closed); the local copy
            // above is only the fallback for a silent push from a server that predates alerts.
            if let content, !Self.carriesAlert(notification) {
                NotificationManager.shared.sendNotification(title: content.title, body: content.body)
            }
            completionHandler(.newData)
            return
        }

        if let type = notification["type"] as? String, type == "traineeReinstalled" {
            // A trainee deleted PPTA and reinstalled it (detected via a Keychain marker that
            // survives uninstall while the app sandbox is wiped). Surface it to their coaches.
            // The server's alert push carries the copy (kept neutral: it states the reinstall, not
            // whether they were locked when they left). The local copy is only the fallback for a
            // silent push from a server that predates alerts.
            if !Self.carriesAlert(notification) {
                let traineeName = (notification["traineeName"] as? String)?.firstNameOnly ?? "Your trainee"
                NotificationManager.shared.sendNotification(
                    title: "\(traineeName) reinstalled PPTA",
                    body: "They deleted the app and reinstalled it, might want to check if they're cheating 🤨"
                )
            }
            completionHandler(.newData)
            return
        }

        if let type = notification["type"] as? String, type == "roleRequestReceived" {
            if !Self.carriesAlert(notification) {
                let name = (notification["requesterName"] as? String)?.firstNameOnly ?? "Someone"
                let role = notification["role"] as? String ?? "coach"
                let roleLabel = role == "trainee" ? "trainee" : "coach"
                NotificationManager.shared.sendNotification(
                    title: "New role request! 🤝",
                    body: "\(name) wants to be your \(roleLabel)."
                )
            }
            completionHandler(.newData)
            return
        }

        // Silent: someone unfriended this user or ended a coach/trainee relationship. No alert —
        // just reload settings so the stale entry disappears from their coach/trainee lists.
        if let type = notification["type"] as? String, type == "relationshipsChanged" {
            UserSettingsManager.shared.loadSettings { loadedSettings in
                DispatchQueue.main.async {
                    UserSettingsManager.shared.userSettings = loadedSettings
                    completionHandler(.newData)
                }
            }
            return
        }

        if let type = notification["type"] as? String, type == "roleRequestAccepted" {
            if !Self.carriesAlert(notification) {
                let name = (notification["acceptorName"] as? String)?.firstNameOnly ?? "Your friend"
                let role = notification["role"] as? String ?? "coach"
                let roleLabel = role == "trainee" ? "trainee" : "coach"
                NotificationManager.shared.sendNotification(
                    title: "Request accepted! 🎉",
                    body: "\(name) accepted your \(roleLabel) request."
                )
            }
            completionHandler(.newData)
            return
        }

        completionHandler(.noData)
    }
    
    /// Called when a local notification fires while the app is in the foreground.
    /// We use this to sync any pending status the DeviceActivity extension wrote
    /// (e.g. grace period expired while the user was already looking at HomeView).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            await UserSettingsManager.shared.applyPendingStatusIfNeeded()
        }
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a notification (including the cold-launch tap).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let type = response.notification.request.content.userInfo["type"] as? String
        if type == ShieldHandoff.requestMoreTimeType {
            Task { @MainActor in
                NotificationManager.shared.requestCoachesPopover()
            }
        }
        completionHandler()
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
            guard let token = fcmToken else { return }
            print("FCM Token: \(token)")
            // Store token in Firestore
            Task {
                await AuthViewModel.shared.updateFCMToken(token)
            }
        }
    
}

@main
struct PPTAMinimalApp: App {
    // Link our AppDelegate to SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var viewModel = AuthViewModel.shared
    @Environment(\.scenePhase) private var scenePhase
    
    /// Onboarding completion is stored per user (by uid) so a new account on the same device sees onboarding.
    private var onboardingComplete: Bool {
        guard let uid = viewModel.userSession?.uid else { return false }
        let key = "onboardingComplete_\(uid)"
        if UserDefaults.standard.bool(forKey: key) { return true }
        // One-time migration: move old device-wide key to this user, then remove it so other accounts get onboarding.
        if UserDefaults.standard.bool(forKey: "onboardingComplete") {
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.removeObject(forKey: "onboardingComplete")
            return true
        }
        return false
    }
    
    var body: some Scene {
        WindowGroup {
            if viewModel.userSession == nil {
                NavigationView {
                    LoginView()
                        .environmentObject(viewModel)
                }
            } else if viewModel.isOnboardingComplete {
                if viewModel.needsScreenTimeReconfigure {
                    // Reinstall of a set-up account: run the trimmed re-grant flow (Screen Time +
                    // confirm apps + limit/pressure) instead of dropping them straight on Home with
                    // monitoring silently off. Coaches/trainees are preserved.
                    OnboardingContainerView(reconfigure: true)
                        .environmentObject(viewModel)
                } else {
                    TabNavigator()
                        .environmentObject(viewModel)
                }
            } else {
                OnboardingContainerView()
                    .environmentObject(viewModel)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Detached unconditionally — a sign-out clears `userSession`, and gating on it would
            // leave a listener attached to the previous user's document.
            if newPhase == .background {
                LockReconciler.shared.stop()
                return
            }
            guard newPhase == .active, viewModel.userSession != nil else { return }
            Task { @MainActor in
                // First, and not awaited behind the rest: a coach lock whose push was dropped is
                // unenforced until this runs, and its first server snapshot is what applies it.
                LockReconciler.shared.start()
                await UserSettingsManager.shared.applyPendingStatusIfNeeded()
                // Names accrue in the App Group whenever a shield is drawn, which can be
                // long after the user's last save.
                UserSettingsManager.shared.refreshSharedAppStatsIfNeeded()
                // Backstop for coach requests parked during onboarding. `FriendsViewModel` drains
                // these too, but only while a view holding it is alive — a friendship accepted
                // while the app was closed would otherwise sit unqueued until the user happened
                // to open Friends.
                await PendingCoachRequestStore.drainUsingCurrentFriendships()
            }
        }
    }
}
