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
        return true
    }
} 