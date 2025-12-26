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
          UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
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
    
    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
        print("@@@ Received Remote Notification: \(notification)")
        if Auth.auth().canHandleNotification(notification){
            completionHandler(.noData)
            return
        }
        if
            let type  = notification["type"] as? String, type == "unlock",
            let coach = notification["by"]   as? String
        {
            print("!!!! Unlock notification received! Type: \(type), By: \(coach)")
            Task { @MainActor in
                DeviceActivityManager.shared.handleRemoteUnlock(from: coach)
                completionHandler(.newData)         
            }
            return
        }

        completionHandler(.noData)
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
    @StateObject var viewModel = AuthViewModel()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    
    // For testing
    private let resetOnboardingForTesting = false // Set to false when not needed
    init() {
        if resetOnboardingForTesting {
            UserDefaults.standard.set(false, forKey: "onboardingComplete")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
               TabNavigator()
                .environmentObject(viewModel)
            } else {
                OnboardingContainerView()
                    .environmentObject(viewModel)
            }

        }
    }
}
