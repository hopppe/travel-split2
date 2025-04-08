//
//  AppDelegate.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import FirebaseCore

// MARK: - App Delegate for Firebase Configuration

/// App delegate for Firebase and other SDK initialization
/// This is required because SwiftUI lifecycle doesn't have a traditional app delegate
class AppDelegate: NSObject, UIApplicationDelegate {
    /// Configure Firebase when the app launches
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize Firebase
        FirebaseApp.configure()
        
        print("Firebase successfully configured in AppDelegate")
        
        // Check if app was launched from a URL (deep link)
        if let url = launchOptions?[.url] as? URL {
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
        handleDeepLink(url)
        return true
    }
    
    /// Handle a deep link by passing it to the SwiftUI layer via the scene's onOpenURL handler
    private func handleDeepLink(_ url: URL) {
        print("Processing deep link: \(url)")
        DispatchQueue.main.async {
            // Use UIApplication.shared.open to trigger the onOpenURL handler in the SwiftUI app
            UIApplication.shared.open(url)
        }
    }
} 