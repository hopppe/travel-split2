//
//  TripParticipantManager.swift
//  travel split
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation
import Combine

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
    func addParticipant(_ user: User) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }
        
        // Check if user is already a participant
        if trip.participants.contains(where: { $0.id == user.id }) {
            tripViewModel.errorMessage = "User is already a participant in this trip"
            return
        }
        
        // Add user to trip
        trip.participants.append(user)
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Remove a participant from the current trip
    func removeParticipant(_ participant: User) -> Bool {
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
    private func isParticipantBalanceZero(_ participant: User, in trip: Trip) -> Bool {
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
        let unclaimedParticipant = User.createUnclaimed(name: name, email: email)
        print("Creating unclaimed participant: \(name) with ID: \(unclaimedParticipant.id)")
        
        // Add to trip
        trip.participants.append(unclaimedParticipant)
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Claim a participant in the current trip
    func claimParticipant(_ participant: User) {
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
        
        // Update the participant to be claimed
        var updatedParticipant = participant
        updatedParticipant.isClaimed = true
        updatedParticipant.claimedByUserId = tripViewModel.currentUser.id
        
        // Update the participant in the trip
        trip.participants[participantIndex] = updatedParticipant
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Find the current user's participant in the trip (handles both direct and claimed participants)
    func findCurrentUserInTrip() -> User? {
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
    func getUnclaimedParticipants(in trip: Trip) -> [User] {
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
    func getPreviousParticipants() -> [User] {
        var allParticipants: [User] = []
        var uniqueParticipantIds = Set<String>()
        let currentUser = tripViewModel.currentUser
        
        // Collect participants from all trips, excluding the current user
        for trip in tripViewModel.trips {
            let otherParticipants = trip.participants.filter { $0.id != currentUser.id }
            
            for participant in otherParticipants {
                // Only add participants that haven't been added yet
                if !uniqueParticipantIds.contains(participant.id) {
                    uniqueParticipantIds.insert(participant.id)
                    allParticipants.append(participant)
                }
            }
        }
        
        // Sort by most recently added (assuming trips are in chronological order)
        // and limit to 12 participants max
        let sortedParticipants = allParticipants.reversed()
        return Array(sortedParticipants.prefix(12))
    }
    
    // Helper for participant claiming UI
    func prepareAndShowParticipantClaimView(with participants: [User], forTrip trip: Trip) {
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