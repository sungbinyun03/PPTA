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

class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                       didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
          FirebaseApp.configure()
          
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
        Auth.auth().setAPNSToken(deviceToken, type: .sandbox)
        print("@@ TOKEN RECEIVED: \(deviceToken.map { String(format: "%02x", $0)}.joined())")
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification notification: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void){
        
        if Auth.auth().canHandleNotification(notification){
            completionHandler(.noData)
            return
        }
    }
 
}

@main
struct PPTAMinimalApp: App {
    // Link our AppDelegate to SwiftUI
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var viewModel = AuthViewModel()
    @AppStorage("onboardingComplete") private var onboardingComplete = false
    
    var body: some Scene {
        WindowGroup {
            if onboardingComplete {
                MainView()
                    .environmentObject(viewModel)
            } else {
                OnboardingContainerView()
                    .environmentObject(viewModel)
            }
        }
    }
}
