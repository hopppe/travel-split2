//
//  TripUserManager.swift
//  travel split
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation
import FirebaseAuth
import Combine

// Manages user authentication and user-related operations
class TripUserManager {
    // References to shared data
    private let tripViewModel: TripViewModel
    
    // Initialize with reference to TripViewModel
    init(tripViewModel: TripViewModel) {
        self.tripViewModel = tripViewModel
    }
    
    // MARK: - User Management
    
    // Update the current user and propagate changes to trips
    func updateUser(_ user: User) {
        // Update current user in the view model
        tripViewModel.currentUser = user
        
        // Persist user preferences locally first (this always works)
        UserDefaults.standard.set(user.name, forKey: "user_name")
        UserDefaults.standard.set(user.email, forKey: "user_email")
        UserDefaults.standard.set(user.id, forKey: "user_id")
        
        // Then try to update in Firestore if authentication is working
        if Auth.auth().currentUser != nil {
            // Update user in any trips where they are a participant
            for (index, trip) in tripViewModel.trips.enumerated() {
                if let participantIndex = trip.participants.firstIndex(where: { $0.id == user.id }) {
                    var updatedTrip = trip
                    updatedTrip.participants[participantIndex] = user
                    
                    // Update trips array
                    tripViewModel.trips[index] = updatedTrip
                    
                    // Update currentTrip if it's the one being changed
                    if tripViewModel.currentTrip?.id == trip.id {
                        tripViewModel.currentTrip = updatedTrip
                    }
                    
                    // Save the updated trip to Firestore
                    FirebaseService.shared.saveTrip(updatedTrip) { success, error in
                        if !success {
                            print("Warning: Failed to update user in trip \(trip.id): \(error?.localizedDescription ?? "unknown error")")
                        }
                    }
                }
            }
        } else {
            print("Note: Local user updated but not synced to Firestore (no authentication)")
        }
    }
    
    // Static method to load or create a user
    static func loadOrCreateUser() -> User {
        // Try to get the Firebase user ID first as the source of truth
        if let firebaseUser = Auth.auth().currentUser {
            let userId = firebaseUser.uid
            
            // Save the Firebase ID to UserDefaults
            UserDefaults.standard.set(userId, forKey: "user_id")
            
            // Get the user's name and email from UserDefaults, or default values
            let userName = UserDefaults.standard.string(forKey: "user_name") ?? "You"
            let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
            
            // Create a user with the Firebase ID
            return User(id: userId, name: userName, email: userEmail, profileImage: nil, isClaimed: true)
        }
        
        // If no Firebase user exists, get the stored user or create a temporary local one
        // Do NOT attempt authentication here - we're deliberately avoiding automatic sign-in
        
        // Check if we have a previously saved user ID
        if let savedUserId = UserDefaults.standard.string(forKey: "user_id") {
            let userName = UserDefaults.standard.string(forKey: "user_name") ?? "You"
            let userEmail = UserDefaults.standard.string(forKey: "user_email") ?? ""
            
            // Create a temporary user with the saved ID
            return User(id: savedUserId, name: userName, email: userEmail, profileImage: nil, isClaimed: true)
        }
        
        // Create a temporary user with a new UUID - but don't authenticate
        let tempId = UUID().uuidString
        UserDefaults.standard.set(tempId, forKey: "user_id")
        UserDefaults.standard.set("You", forKey: "user_name")
        
        // Return a local placeholder user without Firebase authentication
        return User(id: tempId, name: "You", email: "", profileImage: nil, isClaimed: true)
    }
    
    // Helper function for signing in anonymously if needed
    func signInAnonymouslyIfNeeded(completion: @escaping () -> Void) {
        // Use the Firebase service to sign in
        if FirebaseService.shared.isAuthenticated {
            // Already authenticated - proceed
            completion()
            return
        }
        
        // Not authenticated - sign in first
        FirebaseService.shared.signInAnonymously { [weak self] success, error in
            if success {
                // If authentication was successful, update the current user if needed
                if let firebaseUserId = FirebaseService.shared.getCurrentUserId(),
                   self?.tripViewModel.currentUser.id != firebaseUserId {
                    // Update the current user with the Firebase ID
                    var updatedUser = self?.tripViewModel.currentUser ?? User(id: firebaseUserId, name: "You", email: "")
                    updatedUser.id = firebaseUserId
                    self?.tripViewModel.currentUser = updatedUser
                    
                    // Update UserDefaults with the Firebase ID
                    UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
                }
            } else {
                print("Failed to sign in anonymously: \(error?.localizedDescription ?? "Unknown error")")
            }
            
            // Proceed with the completion regardless of success - we'll work with what we have
            completion()
        }
    }
    
    // Make sure the user ID is consistent with Firebase
    func ensureUserIdConsistency() {
        // If we have a Firebase ID, make sure our user model is using it
        if let firebaseUserId = FirebaseService.shared.getCurrentUserId(),
           tripViewModel.currentUser.id != firebaseUserId {
            print("Syncing user ID from \(tripViewModel.currentUser.id) to Firebase ID: \(firebaseUserId)")
            
            // Create updated user with the Firebase ID but keeping other properties
            var updatedUser = tripViewModel.currentUser
            updatedUser.id = firebaseUserId
            
            // Update the current user reference
            tripViewModel.currentUser = updatedUser
            
            // Save the updated user ID to UserDefaults
            UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
        }
    }
} 