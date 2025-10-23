//
//  NotificationService.swift
//  EquiSplit
//
//  Push notification management service using Firebase Cloud Messaging
//

import Foundation
import UIKit
import UserNotifications
import FirebaseMessaging
import FirebaseAuth

/// Manages push notifications for the app using Firebase Cloud Messaging
class NotificationService: NSObject {
    static let shared = NotificationService()

    // Notification permission status
    @Published var notificationPermissionGranted = false

    // Current FCM token
    private var currentFCMToken: String?

    private override init() {
        super.init()
    }

    // MARK: - Permission Management

    /// Request notification permissions from user
    func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.notificationPermissionGranted = granted

                if let error = error {
                    print("Error requesting notification permission: \(error.localizedDescription)")
                    completion(false)
                    return
                }

                if granted {
                    print("Notification permission granted")
                    // Register for remote notifications on main thread
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                    completion(true)
                } else {
                    print("Notification permission denied")
                    completion(false)
                }
            }
        }
    }

    /// Check current notification permission status
    func checkPermissionStatus(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                let granted = settings.authorizationStatus == .authorized
                self.notificationPermissionGranted = granted
                completion(granted)
            }
        }
    }

    // MARK: - FCM Token Management

    /// Save FCM token to Firestore for the current user
    func saveFCMTokenToFirestore(_ token: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, cannot save FCM token")
            return
        }

        self.currentFCMToken = token
        print("Saving FCM token to Firestore for user: \(userId)")

        // Get user's language preference
        let language = LanguageManager.shared.currentLanguage.rawValue

        // Save to Firestore
        FirebaseService.shared.updateUserFCMToken(userId: userId, token: token, language: language) { error in
            if let error = error {
                print("Error saving FCM token to Firestore: \(error.localizedDescription)")
            } else {
                print("Successfully saved FCM token to Firestore")
            }
        }
    }

    /// Remove FCM token from Firestore (e.g., on sign out)
    func removeFCMTokenFromFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, cannot remove FCM token")
            return
        }

        print("Removing FCM token from Firestore for user: \(userId)")

        FirebaseService.shared.removeFCMToken(userId: userId) { error in
            if let error = error {
                print("Error removing FCM token: \(error.localizedDescription)")
            } else {
                print("Successfully removed FCM token")
            }
        }

        self.currentFCMToken = nil
    }

    // MARK: - Notification Preferences

    /// Update user's notification preference
    func updateNotificationPreference(enabled: Bool, completion: @escaping (Error?) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, cannot update notification preference")
            completion(NSError(domain: "NotificationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user"]))
            return
        }

        print("Updating notification preference to: \(enabled)")

        FirebaseService.shared.updateUserNotificationPreference(userId: userId, enabled: enabled) { error in
            if let error = error {
                print("Error updating notification preference: \(error.localizedDescription)")
                completion(error)
            } else {
                print("Successfully updated notification preference")
                completion(nil)
            }
        }
    }

    /// Get user's notification preference from Firestore
    func getNotificationPreference(completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user, defaulting to enabled")
            completion(true)
            return
        }

        FirebaseService.shared.getUserNotificationPreference(userId: userId) { enabled, error in
            if let error = error {
                print("Error fetching notification preference: \(error.localizedDescription)")
                completion(true) // Default to enabled
                return
            }

            completion(enabled)
        }
    }

    // MARK: - Badge Management

    /// Clear app badge count
    func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }

    /// Increment app badge count
    func incrementBadge() {
        DispatchQueue.main.async {
            let currentBadge = UIApplication.shared.applicationIconBadgeNumber
            UIApplication.shared.applicationIconBadgeNumber = currentBadge + 1
        }
    }

    // MARK: - Local Notification Scheduling (for immediate feedback)

    /// Schedule a local notification (used for foreground notifications)
    func scheduleLocalNotification(title: String, body: String, tripId: String, type: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)

        // Add user info for handling notification tap
        content.userInfo = [
            "tripId": tripId,
            "type": type
        ]

        // Trigger immediately
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling local notification: \(error.localizedDescription)")
            } else {
                print("Successfully scheduled local notification")
            }
        }
    }

    // MARK: - Notification Handling

    /// Handle notification tap - navigate to appropriate trip
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        print("Handling notification tap with userInfo: \(userInfo)")

        guard let tripId = userInfo["tripId"] as? String else {
            print("No tripId in notification userInfo")
            return
        }

        // Post notification to navigate to trip
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NavigateToTrip"),
                object: nil,
                userInfo: ["tripId": tripId]
            )
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("Received notification while app in foreground")

        // Show banner, sound, and badge even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        print("User tapped notification")

        let userInfo = response.notification.request.content.userInfo
        handleNotificationTap(userInfo: userInfo)

        completionHandler()
    }
}

// MARK: - MessagingDelegate

extension NotificationService: MessagingDelegate {
    /// Called when FCM token is updated
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM token received: \(fcmToken ?? "nil")")

        guard let token = fcmToken else {
            print("FCM token is nil")
            return
        }

        // Save token to Firestore
        saveFCMTokenToFirestore(token)
    }
}
