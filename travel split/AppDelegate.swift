//
//  AppDelegate.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseMessaging
import UserNotifications

// MARK: - App Delegate for Firebase Configuration

/// App delegate for Firebase and other SDK initialization
/// This is required because SwiftUI lifecycle doesn't have a traditional app delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    // Property to store the URL that launched the app
    var launchURL: URL?

    /// Configure Firebase when the app launches
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()

        // Configure Firestore settings after Firebase is initialized
        let settings = FirestoreSettings()

        // Enable cache with a reasonable size (100MB)
        let cacheSize: Int64 = 100 * 1024 * 1024 // 100MB
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: cacheSize))

        Firestore.firestore().settings = settings

        print("Firebase successfully configured in AppDelegate with offline persistence enabled")

        // Configure push notifications
        configurePushNotifications(application)

        // Check if app was launched from a URL (deep link)
        if let url = launchOptions?[.url] as? URL {
            // Store the launch URL for later use
            self.launchURL = url
            handleDeepLink(url)
        }

        return true
    }

    /// Configure push notifications with Firebase Cloud Messaging
    private func configurePushNotifications(_ application: UIApplication) {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationService.shared

        // Set FCM messaging delegate
        Messaging.messaging().delegate = NotificationService.shared

        print("Push notifications configured")
    }

    /// Called when APNs registration succeeds
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("Successfully registered for remote notifications")

        // Pass device token to FCM
        Messaging.messaging().apnsToken = deviceToken
    }

    /// Called when APNs registration fails
    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error.localizedDescription)")
    }
    
    /// Handle Universal Links (deep links) when the app is opened via a Universal Link
    func application(_ application: UIApplication, 
                     continue userActivity: NSUserActivity) -> Bool {
        // Check if this is a universal link (web URL activity)
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let incomingURL = userActivity.webpageURL {
            print("Received Universal Link: \(incomingURL)")
            
            // Store the URL
            self.launchURL = incomingURL
            
            // Handle the URL directly
            handleDeepLink(incomingURL)
            return true
        }
        return false
    }
    
    /// Handle when the app is opened via a custom URL scheme (travelsplit://)
    func application(_ app: UIApplication, 
                     open url: URL, 
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("App opened with URL scheme: \(url)")
        
        // Store the URL
        self.launchURL = url
        
        handleDeepLink(url)
        return true
    }
    
    /// Handle a deep link by storing it for the SwiftUI app to use
    private func handleDeepLink(_ url: URL) {
        print("Processing deep link in AppDelegate: \(url)")
        // Store the URL for access by the SwiftUI app
        self.launchURL = url
        
        // We don't need to call UIApplication.shared.open() anymore
        // The app will retrieve the URL from launchURL
    }
} 