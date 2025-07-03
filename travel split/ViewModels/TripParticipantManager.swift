//
//  TripParticipantManager.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation
import Combine
import FirebaseAuth
import TravelSplitModels
import TravelSplitServices

// Manages participant-related operations for trips
class TripParticipantManager {
    // References to shared data
    private let tripViewModel: TripViewModel
    
    // Initialize with reference to TripViewModel
    init(tripViewModel: TripViewModel) {
        self.tripViewModel = tripViewModel
    }
    
    // MARK: - Participant Management
    
    // Add the current user to a trip
    func addCurrentUserToTrip(_ trip: Trip) {
        print("Adding current user to trip as a new participant")
        
        var updatedTrip = trip
        let currentUser = tripViewModel.currentUser
        
        // Make sure the current user isn't already in the trip
        if !updatedTrip.participants.contains(where: { $0.id == currentUser.id }) {
            // Add the current user to the trip
            updatedTrip.participants.append(currentUser)
            
            // Update trip in the view model
            tripViewModel.updateTrip(updatedTrip)
        } else {
            print("Current user is already a participant in this trip")
        }
    }
    
    // Add a participant to the current trip
    func addParticipant(_ user: TravelSplitModels.User) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }
        
        // Check if user is already a participant
        if trip.participants.contains(where: { $0.id == user.id }) {
            tripViewModel.errorMessage = "User is already a participant in this trip"
            return
        }
        
        // Create a copy of the user to potentially modify
        var userToAdd = user
        
        // If this is a real user (not an unclaimed placeholder), ensure they're added to the trip on their device
        // We identify real users by the isClaimed flag
        if userToAdd.isClaimed {
            print("Adding real user to trip: \(userToAdd.name) (ID: \(userToAdd.id))")
            
            // Special handling for users with 'unclaimed_' IDs that have been claimed
            // This is a critical case: the user was once a placeholder but is now claimed
            if userToAdd.id.hasPrefix("unclaimed_") {
                print("Detected previously unclaimed user that is now claimed")
                
                // Check if the claimedByUserId is set, which is the Firebase ID of the user who claimed it
                if let claimedById = userToAdd.claimedByUserId, !claimedById.isEmpty, !claimedById.contains("-") {
                    print("Using claimedByUserId as the real Firebase ID: \(claimedById)")
                    // Use the claimedByUserId as the Firebase ID, which is unique to the user
                    userToAdd.id = claimedById
                } else {
                    // Add a unique suffix to ensure we don't have duplicate IDs
                    // This is a fallback case - the ID is still not ideal but at least it's unique
                    userToAdd.id += "_added_\(UUID().uuidString.prefix(8))"
                    print("Using modified ID to ensure uniqueness: \(userToAdd.id)")
                }
            }
            
            // Check if the user ID looks like a Firebase ID (not a UUID)
            // Firebase IDs don't contain hyphens, while UUIDs do
            if userToAdd.id.contains("-") {
                print("Warning: User ID appears to be a UUID, not a Firebase ID: \(userToAdd.id)")
                print("Previous participants may be using local UUIDs instead of Firebase IDs")
            }
            
            // Make a final uniqueness check to avoid duplicate IDs
            if trip.participants.contains(where: { $0.id == userToAdd.id }) {
                print("⚠️ Potential duplicate ID detected - adding unique suffix")
                userToAdd.id += "_unique_\(UUID().uuidString.prefix(8))"
            }
            
            // Add user to trip with potentially corrected ID
            trip.participants.append(userToAdd)
            
            // Update trip in the view model
            tripViewModel.updateTrip(trip)
            
            // Print participants to check proper updating
            print("Trip now has \(trip.participants.count) participants:")
            for (index, p) in trip.participants.enumerated() {
                print("  \(index): \(p.name) (ID: \(p.id), isClaimed: \(p.isClaimed))")
            }
        } else {
            // For unclaimed participants, just add them to the trip
            trip.participants.append(userToAdd)
            tripViewModel.updateTrip(trip)
        }
    }
    
    // Remove a participant from the current trip
    func removeParticipant(_ participant: TravelSplitModels.User) -> Bool {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return false
        }
        
        // Check if user is the current user - shouldn't be able to remove self this way
        if participant.id == tripViewModel.currentUser.id || participant.claimedByUserId == tripViewModel.currentUser.id {
            tripViewModel.errorMessage = "Cannot remove yourself from the group. Use 'Leave Group' instead."
            return false
        }
        
        // Check if participant has a balance
        let hasBalance = !isParticipantBalanceZero(participant, in: trip)
        if hasBalance {
            return false
        }
        
        // Remove participant from trip
        trip.participants.removeAll(where: { $0.id == participant.id })
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
        return true
    }
    
    // Helper method to check if a participant's balance is zero
    private func isParticipantBalanceZero(_ participant: TravelSplitModels.User, in trip: Trip) -> Bool {
        // Calculate what this participant has paid and what they owe
        var balance: Double = 0
        
        for expense in trip.expenses {
            // Get expense amount converted to the trip's base currency
            let expenseCurrency = expense.currencyCode ?? trip.baseCurrencyCode
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            // Check if participant paid for this expense
            if expense.paidBy.id == participant.id {
                // Participant paid, so they're owed money
                balance += convertedAmount
            }
            
            // Check how much participant owes for this expense
            for share in expense.shares {
                if share.user.id == participant.id {
                    // Convert the share amount to trip's base currency
                    let convertedShareAmount = CurrencyConverterService.shared.convert(
                        amount: share.amount,
                        from: expenseCurrency,
                        to: trip.baseCurrencyCode
                    )
                    
                    // Participant has a share in this expense, reduce balance
                    balance -= convertedShareAmount
                }
            }
        }
        
        return abs(balance) < 0.01 // Using a small epsilon for floating-point comparison
    }
    
    // Add an unclaimed participant (placeholder) to the current trip
    func addUnclaimedParticipant(name: String, email: String = "") {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }
        
        // Create unclaimed participant with the current authenticated user as the creator
        let unclaimedParticipant = TravelSplitModels.User.createUnclaimed(name: name, email: email)
        print("Creating unclaimed participant: \(name) with ID: \(unclaimedParticipant.id)")
        
        // Add to trip
        trip.participants.append(unclaimedParticipant)
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Claim a participant in the current trip
    func claimParticipant(_ participant: TravelSplitModels.User) {
        print("Claiming participant: \(participant.name) in trip")
        
        guard var trip = tripViewModel.currentTrip else {
            print("Error: No current trip when claiming participant")
            return
        }
        
        // Find the participant in the trip
        guard let participantIndex = trip.participants.firstIndex(where: { $0.id == participant.id }) else {
            print("Error: Participant not found in trip")
            return
        }
        
        // Determine the best name to use for the claimed participant
        // Priority: 1. Firebase display name, 2. Saved user name (if not "user"), 3. Keep original placeholder name
        let bestName: String
        let currentUser = tripViewModel.currentUser
        
        // Check if we have a proper Firebase display name
        if let firebaseUser = Auth.auth().currentUser,
           let displayName = firebaseUser.displayName,
           !displayName.isEmpty,
           displayName != "user" {
            bestName = displayName
            print("Using Firebase display name: \(displayName)")
        }
        // Check if current user has a proper name (not "user")
        else if !currentUser.name.isEmpty && currentUser.name != "user" {
            bestName = currentUser.name
            print("Using current user name: \(currentUser.name)")
        }
        // Fall back to keeping the original placeholder name
        else {
            bestName = participant.name
            print("Keeping original placeholder name: \(participant.name) (current user name is '\(currentUser.name)')")
        }
        
        // Update the participant to be claimed
        var updatedParticipant = participant
        updatedParticipant.isClaimed = true
        updatedParticipant.claimedByUserId = currentUser.id
        updatedParticipant.name = bestName
        
        // Update the participant in the trip
        trip.participants[participantIndex] = updatedParticipant
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
        
        print("Participant claimed successfully: \(updatedParticipant.name) (isClaimed: \(updatedParticipant.isClaimed), claimedBy: \(updatedParticipant.claimedByUserId ?? "none"))")
    }
    
    // Find the current user's participant in the trip (handles both direct and claimed participants)
    func findCurrentUserInTrip() -> TravelSplitModels.User? {
        guard let trip = tripViewModel.currentTrip else {
            return nil
        }
        
        let currentUser = tripViewModel.currentUser
        
        // First check if the current user is directly in the trip
        if let directUser = trip.participants.first(where: { $0.id == currentUser.id }) {
            return directUser
        }
        
        // Then check if the current user has claimed any participant
        return trip.participants.first(where: { 
            $0.isClaimed && $0.claimedByUserId == currentUser.id 
        })
    }
    
    // Get a list of unclaimed participants in a trip
    func getUnclaimedParticipants(in trip: Trip) -> [TravelSplitModels.User] {
        let currentUser = tripViewModel.currentUser
        
        // Return all participants that are not claimed and either:
        // 1. Have no email (can be claimed by anyone), OR
        // 2. Have an email that matches the current user's email
        return trip.participants.filter { participant in
            !participant.isClaimed && 
            (participant.email.isEmpty || 
             participant.email.lowercased() == currentUser.email.lowercased())
        }
    }
    
    // Get previous participants from all trips
    func getPreviousParticipants(excludingParticipantsFrom trip: Trip? = nil) -> [TravelSplitModels.User] {
        var allParticipants: [TravelSplitModels.User] = []
        var uniqueParticipantIds = Set<String>()
        let currentUser = tripViewModel.currentUser
        
        print("Getting previous participants (excluding from trip: \(trip?.id ?? "none"))")
        
        // Collect participants from all trips, excluding the current user
        for tripItem in tripViewModel.trips {
            let otherParticipants = tripItem.participants.filter { participant in
                // Exclude current user
                participant.id != currentUser.id && 
                // Only include claimed participants (not placeholders)
                participant.isClaimed &&
                // If a trip is provided, exclude participants already in that trip
                (trip == nil || !(trip?.participants.contains(where: { $0.id == participant.id }) ?? false))
            }
            
            for participant in otherParticipants {
                // Only add participants that haven't been added yet
                if !uniqueParticipantIds.contains(participant.id) {
                    uniqueParticipantIds.insert(participant.id)
                    
                    // Check if this participant has a Firebase-style ID or a UUID
                    // For debugging purposes
                    if participant.id.contains("-") {
                        print("Previous participant with UUID-style ID: \(participant.name) (ID: \(participant.id))")
                    } else {
                        print("Previous participant with Firebase-style ID: \(participant.name) (ID: \(participant.id))")
                    }
                    
                    allParticipants.append(participant)
                }
            }
        }
        
        // Sort by most recently added (assuming trips are in chronological order)
        // and limit to 12 participants max
        let sortedParticipants = allParticipants.reversed()
        let result = Array(sortedParticipants.prefix(12))
        
        print("Found \(result.count) previous participants to display")
        return result
    }
    
    // Helper for participant claiming UI
    func prepareAndShowParticipantClaimView(with participants: [TravelSplitModels.User], forTrip trip: Trip) {
        print("Preparing to show participant claim view with \(participants.count) participants")
        
        // Add trip to local trips array if not already there
        if !tripViewModel.trips.contains(where: { $0.id == trip.id }) {
            tripViewModel.trips.append(trip)
        }
        
        // First reset the flag in case it was already true
        tripViewModel.showParticipantClaimingView = false
        
        // Update state in one batch to avoid race conditions
        DispatchQueue.main.async {
            self.tripViewModel.currentTrip = trip
            self.tripViewModel.potentialClaimableParticipants = participants
            
            // Force a delay before setting the flag to ensure the UI has time to react
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("Setting showParticipantClaimingView to true")
                self.tripViewModel.showParticipantClaimingView = true
                self.tripViewModel.logParticipantClaimingState()
            }
        }
    }
} 