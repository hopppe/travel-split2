//
//  AppDelegate.swift
//  free split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

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
        
        // Check if app was launched from a URL (deep link)
        if let url = launchOptions?[.url] as? URL {
            // Store the launch URL for later use
            self.launchURL = url
            handleDeepLink(url)
        }
        
        return true
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