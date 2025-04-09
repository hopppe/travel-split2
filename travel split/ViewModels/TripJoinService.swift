//
//  TripJoinService.swift
//  travel split
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation
import FirebaseAuth
import Combine

// Manages joining and sharing trips
class TripJoinService {
    // References to shared data
    private let tripViewModel: TripViewModel
    private let userManager: TripUserManager
    private let participantManager: TripParticipantManager
    
    // Initialize with reference to TripViewModel and other managers
    init(tripViewModel: TripViewModel, userManager: TripUserManager, participantManager: TripParticipantManager) {
        self.tripViewModel = tripViewModel
        self.userManager = userManager
        self.participantManager = participantManager
    }
    
    // MARK: - Trip Sharing & Joining
    
    // Generate shareable content for the current trip
    func generateShareLink() -> String {
        guard let trip = tripViewModel.currentTrip else {
            return ""
        }
        
        return FirebaseService.shared.generateShareMessage(
            inviteCode: trip.inviteCode, 
            tripName: trip.name
        )
    }
    
    // Join an existing trip using an invite code
    func joinTrip(withInviteCode code: String, completion: ((Bool) -> Void)? = nil) {
        tripViewModel.isLoading = true
        tripViewModel.errorMessage = nil
        
        print("Starting join trip process with code: \(code)")
        
        // First ensure we have Firebase authentication and consistent user ID
        userManager.signInAnonymouslyIfNeeded {
            // Ensure user ID consistency
            self.userManager.ensureUserIdConsistency()
            
            print("Current authenticated Firebase ID: \(FirebaseService.shared.getCurrentUserId() ?? "none")")
            print("Current user ID in app: \(self.tripViewModel.currentUser.id)")
            
            // Check if we already have this trip locally
            if let existingTrip = self.tripViewModel.trips.first(where: { $0.inviteCode == code }) {
                print("Found trip locally with code: \(code), ID: \(existingTrip.id)")
                
                // Check if already a participant
                if existingTrip.participants.contains(where: { $0.id == self.tripViewModel.currentUser.id }) {
                    print("User is already a participant in this trip")
                    self.tripViewModel.errorMessage = "You are already a participant in this trip"
                    self.tripViewModel.isLoading = false
                    completion?(false)
                    return
                }
                
                // Check for unclaimed participants
                let unclaimedParticipants = self.participantManager.getUnclaimedParticipants(in: existingTrip)
                
                if !unclaimedParticipants.isEmpty {
                    print("Found \(unclaimedParticipants.count) unclaimed participants, showing claim view")
                    self.tripViewModel.isLoading = false
                    
                    // Use the dedicated helper method to show the claiming view
                    self.participantManager.prepareAndShowParticipantClaimView(with: unclaimedParticipants, forTrip: existingTrip)
                    completion?(false)
                    return
                }
                
                // Add self to the trip
                print("Adding current user to trip")
                var updatedTrip = existingTrip
                updatedTrip.participants.append(self.tripViewModel.currentUser)
                
                // Save the updated trip to Firestore
                print("Saving updated trip to Firestore")
                FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.tripViewModel.isLoading = false
                    
                    if let error = error {
                        print("Error saving updated trip: \(error.localizedDescription)")
                        self.tripViewModel.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion?(false)
                        return
                    }
                    
                    if success {
                        print("Successfully joined trip!")
                        if let index = self.tripViewModel.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                            self.tripViewModel.trips[index] = updatedTrip
                        } else {
                            // Trip might have been removed from local cache
                            self.tripViewModel.trips.append(updatedTrip)
                        }
                        self.tripViewModel.currentTrip = updatedTrip
                        
                        // Set up the trip listener to keep the trip data in sync
                        self.tripViewModel.setupTripListener(for: updatedTrip.id)
                        completion?(true)
                    } else {
                        print("Trip save reported no success but no error")
                        self.tripViewModel.errorMessage = "Unknown error joining trip"
                        completion?(false)
                    }
                }
                return
            }
            
            // Trip not found locally, fetch from Firestore
            print("Trip not found locally, fetching from Firestore")
            FirebaseService.shared.fetchTrip(withInviteCode: code) { [weak self] trip, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching trip: \(error.localizedDescription)")
                    self.tripViewModel.errorMessage = "Error finding trip: \(error.localizedDescription)"
                    self.tripViewModel.isLoading = false
                    completion?(false)
                    return
                }
                
                guard var trip = trip else {
                    print("No trip found with invite code: \(code)")
                    self.tripViewModel.errorMessage = "Invalid invite code or trip not found"
                    self.tripViewModel.isLoading = false
                    completion?(false)
                    return
                }
                
                print("Fetched trip from Firestore: \(trip.id), \(trip.name)")
                
                // Check if already a participant
                if trip.participants.contains(where: { $0.id == self.tripViewModel.currentUser.id }) {
                    print("User is already a participant in this trip")
                    self.tripViewModel.errorMessage = "You are already a participant in this trip"
                    self.tripViewModel.isLoading = false
                    completion?(false)
                    return
                }
                
                // Check for unclaimed participants
                let unclaimedParticipants = self.participantManager.getUnclaimedParticipants(in: trip)
                
                if !unclaimedParticipants.isEmpty {
                    print("Found \(unclaimedParticipants.count) unclaimed participants, showing claim view")
                    self.tripViewModel.isLoading = false
                    
                    // Use the dedicated helper method to show the claiming view
                    self.participantManager.prepareAndShowParticipantClaimView(with: unclaimedParticipants, forTrip: trip)
                    completion?(false)
                    return
                }
                
                // No unclaimed participants - add self to trip
                print("Adding current user to trip")
                
                // Always use the Firebase ID when joining a trip
                let firebaseUserId = FirebaseService.shared.getCurrentUserId()
                if let firebaseUserId = firebaseUserId, self.tripViewModel.currentUser.id != firebaseUserId {
                    print("Updating user ID from \(self.tripViewModel.currentUser.id) to Firebase ID: \(firebaseUserId)")
                    var updatedUser = self.tripViewModel.currentUser
                    updatedUser.id = firebaseUserId
                    self.tripViewModel.currentUser = updatedUser
                    UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
                }
                
                // Add the current user to the trip
                trip.participants.append(self.tripViewModel.currentUser)
                
                // Save updated trip to Firestore
                print("Saving updated trip to Firestore with user added")
                FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.tripViewModel.isLoading = false
                    
                    if let error = error {
                        print("Error saving updated trip: \(error.localizedDescription)")
                        self.tripViewModel.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion?(false)
                        return
                    }
                    
                    if success {
                        print("Successfully joined trip!")
                        // Add trip to local trips array if not already there
                        if !self.tripViewModel.trips.contains(where: { $0.id == trip.id }) {
                            self.tripViewModel.trips.append(trip)
                        }
                        self.tripViewModel.currentTrip = trip
                        
                        // Set up the trip listener to keep the trip data in sync
                        self.tripViewModel.setupTripListener(for: trip.id)
                        completion?(true)
                    } else {
                        print("Trip save reported no success but no error")
                        self.tripViewModel.errorMessage = "Unknown error joining trip"
                        completion?(false)
                    }
                }
            }
        }
    }
    
    /// Automatically join a trip with the given invite code without showing the join sheet
    func autoJoinTrip(withInviteCode code: String, completion: @escaping (Bool) -> Void) {
        tripViewModel.isLoading = true
        tripViewModel.errorMessage = nil
        
        print("Starting auto-join process with code: \(code)")
        
        // First ensure we have Firebase authentication
        userManager.signInAnonymouslyIfNeeded {
            // Ensure user ID consistency
            self.userManager.ensureUserIdConsistency()
            
            print("Current authenticated Firebase ID: \(FirebaseService.shared.getCurrentUserId() ?? "none")")
            print("Current user ID in app: \(self.tripViewModel.currentUser.id)")
            
            // Check if we already have this trip locally
            if let existingTrip = self.tripViewModel.trips.first(where: { $0.inviteCode == code }) {
                print("Found trip locally with code: \(code), ID: \(existingTrip.id)")
                
                // Already a member of this trip
                if existingTrip.participants.contains(where: { $0.id == self.tripViewModel.currentUser.id }) {
                    print("User is already a participant in this trip - selecting it")
                    // We're already in this trip - select it and return success
                    self.tripViewModel.currentTrip = existingTrip
                    self.tripViewModel.isLoading = false
                    completion(true)
                    return
                }
                
                // Check for unclaimed participants
                let unclaimedParticipants = self.participantManager.getUnclaimedParticipants(in: existingTrip)
                
                if !unclaimedParticipants.isEmpty {
                    print("Found \(unclaimedParticipants.count) unclaimed participants, showing claim view")
                    self.tripViewModel.isLoading = false
                    
                    // Use the dedicated helper method to show the claiming view
                    self.participantManager.prepareAndShowParticipantClaimView(with: unclaimedParticipants, forTrip: existingTrip)
                    
                    // Need user input for claiming
                    completion(false)
                    return
                }
                
                // No unclaimed participants - add self to the trip
                print("Adding current user to trip")
                var updatedTrip = existingTrip
                updatedTrip.participants.append(self.tripViewModel.currentUser)
                
                // Save the updated trip to Firestore
                print("Saving updated trip to Firestore")
                FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.tripViewModel.isLoading = false
                    
                    if let error = error {
                        print("Error saving updated trip: \(error.localizedDescription)")
                        self.tripViewModel.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    if success {
                        print("Successfully joined trip!")
                        if let index = self.tripViewModel.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                            self.tripViewModel.trips[index] = updatedTrip
                        } else {
                            // Trip might have been removed from local cache
                            self.tripViewModel.trips.append(updatedTrip)
                        }
                        self.tripViewModel.currentTrip = updatedTrip
                        
                        // Set up the trip listener to keep the trip data in sync
                        self.tripViewModel.setupTripListener(for: updatedTrip.id)
                        completion(true)
                    } else {
                        print("Trip save reported no success but no error")
                        self.tripViewModel.errorMessage = "Unknown error joining trip"
                        completion(false)
                    }
                }
                return
            }
            
            // Trip not found locally, fetch from Firestore
            print("Trip not found locally, fetching from Firestore")
            FirebaseService.shared.fetchTrip(withInviteCode: code) { [weak self] trip, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching trip: \(error.localizedDescription)")
                    self.tripViewModel.errorMessage = "Error finding trip: \(error.localizedDescription)"
                    self.tripViewModel.isLoading = false
                    completion(false)
                    return
                }
                
                guard var trip = trip else {
                    print("No trip found with invite code: \(code)")
                    self.tripViewModel.errorMessage = "Invalid invite code or trip not found"
                    self.tripViewModel.isLoading = false
                    completion(false)
                    return
                }
                
                print("Fetched trip from Firestore: \(trip.id), \(trip.name)")
                
                // Check if already a participant
                if trip.participants.contains(where: { $0.id == self.tripViewModel.currentUser.id }) {
                    print("User is already a participant in this trip - selecting it")
                    // We're already in this trip - select it and return success
                    self.tripViewModel.currentTrip = trip
                    
                    // Add trip to local trips array if not already there
                    if !self.tripViewModel.trips.contains(where: { $0.id == trip.id }) {
                        self.tripViewModel.trips.append(trip)
                    }
                    
                    self.tripViewModel.isLoading = false
                    completion(true)
                    return
                }
                
                // Check for unclaimed participants
                let unclaimedParticipants = self.participantManager.getUnclaimedParticipants(in: trip)
                
                if !unclaimedParticipants.isEmpty {
                    print("Found \(unclaimedParticipants.count) unclaimed participants, showing claim view")
                    self.tripViewModel.isLoading = false
                    
                    // Use the dedicated helper method to show the claiming view
                    self.participantManager.prepareAndShowParticipantClaimView(with: unclaimedParticipants, forTrip: trip)
                    
                    // Need user input for claiming
                    completion(false)
                    return
                }
                
                // No unclaimed participants - add self to trip
                print("Adding current user to trip")
                
                // Always use the Firebase ID when joining a trip
                let firebaseUserId = FirebaseService.shared.getCurrentUserId()
                if let firebaseUserId = firebaseUserId, self.tripViewModel.currentUser.id != firebaseUserId {
                    print("Updating user ID from \(self.tripViewModel.currentUser.id) to Firebase ID: \(firebaseUserId)")
                    var updatedUser = self.tripViewModel.currentUser
                    updatedUser.id = firebaseUserId
                    self.tripViewModel.currentUser = updatedUser
                    UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
                }
                
                // Add the current user to the trip
                trip.participants.append(self.tripViewModel.currentUser)
                
                // Save updated trip to Firestore
                print("Saving updated trip to Firestore with user added")
                FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.tripViewModel.isLoading = false
                    
                    if let error = error {
                        print("Error saving updated trip: \(error.localizedDescription)")
                        self.tripViewModel.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    if success {
                        print("Successfully joined trip!")
                        // Add trip to local trips array if not already there
                        if !self.tripViewModel.trips.contains(where: { $0.id == trip.id }) {
                            self.tripViewModel.trips.append(trip)
                        }
                        self.tripViewModel.currentTrip = trip
                        
                        // Set up the trip listener to keep the trip data in sync
                        self.tripViewModel.setupTripListener(for: trip.id)
                        completion(true)
                    } else {
                        print("Trip save reported no success but no error")
                        self.tripViewModel.errorMessage = "Unknown error joining trip"
                        completion(false)
                    }
                }
            }
        }
    }
} 