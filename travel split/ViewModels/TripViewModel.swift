//
//  TripViewModel.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import Foundation
import SwiftUI
import Combine
import FirebaseAuth

// ViewModel to handle Trip operations
class TripViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var currentTrip: Trip?
    @Published var currentUser: User
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // New states for participant claiming
    @Published var potentialClaimableParticipants: [User] = []
    @Published var showParticipantClaimingView = false
    
    // Firestore listeners
    private var tripListeners: [String: Any] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    // Initialize with the current user
    init(currentUser: User) {
        self.currentUser = currentUser
        loadTrips()
    }
    
    // MARK: - Trip Management
    
    func loadTrips() {
        isLoading = true
        
 
        
        isLoading = false
    }
    
    // Set up a real-time listener for trip updates
    private func setupTripListener(for tripId: String) {
        // Remove any existing listener
        if let listener = tripListeners[tripId] {
            FirebaseService.shared.stopListening(listener: listener)
        }
        
        // Set up a new listener
        let listener = FirebaseService.shared.listenForTripUpdates(tripId: tripId) { [weak self] updatedTrip, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error listening for trip updates: \(error.localizedDescription)")
                return
            }
            
            if let updatedTrip = updatedTrip {
                // Update the trip in our array
                if let index = self.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                    self.trips[index] = updatedTrip
                    
                    // If this is the current trip, update it
                    if self.currentTrip?.id == updatedTrip.id {
                        self.currentTrip = updatedTrip
                    }
                } else {
                    // This is a new trip, add it
                    self.trips.append(updatedTrip)
                }
            }
        }
        
        if let listener = listener {
            tripListeners[tripId] = listener
        }
    }
    
    // Create a new trip and save to Firestore
    func createNewTrip(name: String, description: String, initialParticipants: [User] = []) {
        isLoading = true
        
        var newTrip = Trip.create(
            name: name,
            description: description,
            creator: currentUser
        )
        
        // Add initial participants if any (besides the creator who is already added)
        if !initialParticipants.isEmpty {
            newTrip.participants.append(contentsOf: initialParticipants)
        }
        
        // Save to Firestore
        FirebaseService.shared.saveTrip(newTrip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error creating trip: \(error.localizedDescription)"
                return
            }
            
            if success {
                self.trips.append(newTrip)
                self.currentTrip = newTrip
                self.setupTripListener(for: newTrip.id)
            }
        }
    }
    
    func selectTrip(_ trip: Trip) {
        currentTrip = trip
    }
    
    // MARK: - Trip Sharing & Joining
    
    // Generate shareable content for the current trip
    func generateShareLink() -> String {
        guard let trip = currentTrip else {
            return ""
        }
        
        return FirebaseService.shared.generateShareMessage(
            inviteCode: trip.inviteCode, 
            tripName: trip.name
        )
    }
    
    // Join an existing trip using an invite code
    func joinTrip(withInviteCode code: String) {
        isLoading = true
        self.errorMessage = nil
        
        // First ensure we have a Firebase authentication
        signInAnonymouslyIfNeeded {
            // Check if we already have this trip locally
            if let existingTrip = self.trips.first(where: { $0.inviteCode == code }) {
                // Already a member of this trip
                if existingTrip.participants.contains(where: { $0.id == self.currentUser.id }) {
                    self.errorMessage = "You are already a participant in this trip"
                    self.isLoading = false
                    return
                }
                
                // Check for unclaimed participants that could be claimed
                let unclaimedParticipants = self.getUnclaimedParticipants(in: existingTrip)
                
                if !unclaimedParticipants.isEmpty {
                    // We have unclaimed participants - show the claim view instead of auto-joining
                    self.potentialClaimableParticipants = unclaimedParticipants
                    self.showParticipantClaimingView = true
                    self.isLoading = false
                    self.currentTrip = existingTrip
                    return
                }
                
                // No unclaimed participants - add self to the trip locally
                var updatedTrip = existingTrip
                updatedTrip.participants.append(self.currentUser)
                
                // Save the updated trip to Firestore
                FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        return
                    }
                    
                    if success {
                        if let index = self.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                            self.trips[index] = updatedTrip
                        }
                        self.currentTrip = updatedTrip
                    }
                }
                return
            }
            
            // Fetch trip from Firestore
            FirebaseService.shared.fetchTrip(withInviteCode: code) { [weak self] trip, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error finding trip: \(error.localizedDescription)"
                    return
                }
                
                guard var trip = trip else {
                    self.errorMessage = "Invalid invite code or trip not found"
                    return
                }
                
                // Check if already a participant
                if trip.participants.contains(where: { $0.id == self.currentUser.id }) {
                    self.errorMessage = "You are already a participant in this trip"
                    return
                }
                
                // Check for unclaimed participants that could be claimed
                let unclaimedParticipants = self.getUnclaimedParticipants(in: trip)
                
                if !unclaimedParticipants.isEmpty {
                    // We have unclaimed participants - show the claim view instead of auto-joining
                    self.potentialClaimableParticipants = unclaimedParticipants
                    self.showParticipantClaimingView = true
                    self.currentTrip = trip
                    
                    // Add trip to local trips array if not already there
                    if !self.trips.contains(where: { $0.id == trip.id }) {
                        self.trips.append(trip)
                    }
                    
                    return
                }
                
                // No unclaimed participants - add self to trip
                // Make sure we're using the current Firebase user ID
                if let firebaseUserId = FirebaseService.shared.getCurrentUserId() {
                    // Only update the local user model if the IDs don't match
                    if self.currentUser.id != firebaseUserId {
                        print("Updating user ID from \(self.currentUser.id) to Firebase ID: \(firebaseUserId)")
                        
                        // Create updated user with the Firebase ID
                        var updatedUser = self.currentUser
                        updatedUser.id = firebaseUserId
                        
                        // Update the current user reference
                        self.currentUser = updatedUser
                        
                        // Save the updated user ID to UserDefaults
                        UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
                    }
                }
                trip.participants.append(self.currentUser)
                
                // Save updated trip to Firestore
                FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        return
                    }
                    
                    if success {
                        // Add trip to local trips array if not already there
                        if !self.trips.contains(where: { $0.id == trip.id }) {
                            self.trips.append(trip)
                        }
                        self.currentTrip = trip
                        // Set up the trip listener to keep the trip data in sync
                        self.setupTripListener(for: trip.id)
                        // Load trips again to ensure we have the latest data
                        self.loadTrips()
                    }
                }
            }
        }
    }
    
    // MARK: - Expense Management
    
    func addExpenseToCurrentTrip(title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD") {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Safeguard against using an invalid paidBy user
        // Make sure the paidBy user is in the participant list (and get the latest version)
        if let validPaidBy = trip.participants.first(where: { $0.id == paidBy.id }) {
            var expense: Expense
            
            switch splitType {
            case .equal:
                // Make sure we're using valid participant references from the trip
                // This prevents issues with stale user references
                expense = Expense.createEqual(
                    title: title,
                    amount: amount,
                    paidBy: validPaidBy,
                    participants: trip.participants,
                    category: category,
                    currencyCode: currencyCode
                )
            case .custom:
                guard let shares = customShares, !shares.isEmpty else {
                    errorMessage = "Custom shares must be provided for custom split"
                    return
                }
                
                // Validate and update shares to use valid participant references
                var validShares = [ExpenseShare]()
                for share in shares {
                    if let validUser = trip.participants.first(where: { $0.id == share.user.id }) {
                        let validShare = ExpenseShare(user: validUser, amount: share.amount, percentage: share.percentage)
                        validShares.append(validShare)
                    } else {
                        errorMessage = "Invalid participant in expense share"
                        return
                    }
                }
                
                expense = Expense.createCustom(
                    title: title,
                    amount: amount,
                    paidBy: validPaidBy,
                    shares: validShares,
                    category: category,
                    currencyCode: currencyCode
                )
            }
            
            // Add expense to trip
            trip.expenses.append(expense)
            
            // Update trip in array locally
            if let index = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[index] = trip
                currentTrip = trip
            }
            
            // Save trip with new expense to Firestore
            isLoading = true
            FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error saving expense: \(error.localizedDescription)"
                }
            }
        } else {
            errorMessage = "Selected payer is not a valid participant in this trip"
        }
    }
    
    func updateExpense(id: String, title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD") {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Find the expense index in the trip
        guard let expenseIndex = trip.expenses.firstIndex(where: { $0.id == id }) else {
            errorMessage = "Expense not found"
            return
        }
        
        var updatedExpense: Expense
        
        switch splitType {
        case .equal:
            updatedExpense = Expense.createEqual(
                title: title,
                amount: amount,
                paidBy: paidBy,
                participants: trip.participants,
                category: category,
                currencyCode: currencyCode
            )
        case .custom:
            guard let shares = customShares, !shares.isEmpty else {
                errorMessage = "Custom shares must be provided for custom split"
                return
            }
            updatedExpense = Expense.createCustom(
                title: title,
                amount: amount,
                paidBy: paidBy,
                shares: shares,
                category: category,
                currencyCode: currencyCode
            )
        }
        
        // Preserve the original ID
        let originalId = trip.expenses[expenseIndex].id
        updatedExpense = Expense(
            id: originalId,
            title: updatedExpense.title,
            description: updatedExpense.description,
            amount: updatedExpense.amount,
            date: updatedExpense.date,
            category: updatedExpense.category,
            paidBy: updatedExpense.paidBy,
            shares: updatedExpense.shares,
            currencyCode: updatedExpense.currencyCode
        )
        
        // Update the expense
        trip.expenses[expenseIndex] = updatedExpense
        
        // Update trip in array locally
        if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[tripIndex] = trip
            currentTrip = trip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error updating expense: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteExpense(withId id: String) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Remove the expense
        trip.expenses.removeAll(where: { $0.id == id })
        
        // Update trip in array locally
        if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[tripIndex] = trip
            currentTrip = trip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error deleting expense: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Trip Management
    
    // Delete a trip by ID - keeps for backward compatibility
    func deleteTrip(withId id: String) {
        // Remove from local array first
        trips.removeAll(where: { $0.id == id })
        
        // If the deleted trip was the current trip, clear the current trip
        if currentTrip?.id == id {
            currentTrip = nil
        }
        
        // Delete from Firestore
        FirebaseService.shared.deleteTrip(withId: id) { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = "Error deleting trip: \(error.localizedDescription)"
            }
        }
    }
    
    // Leave a trip - Remove the current user from participants
    func leaveTrip(trip: Trip) {
        isLoading = true
        
        // Check if the user has any outstanding balances
        let userBalance = getUserBalanceInTrip(trip)
        
        // If balance is not zero, user cannot leave
        if abs(userBalance) > 0.01 { // Using a small epsilon for floating-point comparison
            isLoading = false
            errorMessage = "You cannot leave the group until your balance is zero. Please settle all debts first."
            return
        }
        
        // Create a copy of the trip without the current user
        var updatedTrip = trip
        
        // Remove the current user from participants
        // We need to check for both direct ID match and claimed participant match
        updatedTrip.participants.removeAll(where: { 
            $0.id == currentUser.id || $0.claimedByUserId == currentUser.id 
        })
        
        // If this results in an empty trip, we should delete the trip
        if updatedTrip.participants.isEmpty {
            // Delete the trip entirely
            deleteTrip(withId: trip.id)
            isLoading = false
            return
        }
        
        // Update local array first
        // Remove the trip from our local trips array since we're no longer in it
        self.trips.removeAll(where: { $0.id == trip.id })
        
        // Clear current trip if it was the one we left
        if currentTrip?.id == trip.id {
            currentTrip = nil
        }
        
        // Save the updated trip to Firestore (with the user removed)
        FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error leaving trip: \(error.localizedDescription)"
                
                // Add the trip back to our local array if there was an error
                if !self.trips.contains(where: { $0.id == trip.id }) {
                    self.trips.append(trip)
                }
            } else {
                print("Successfully left trip: \(trip.name)")
            }
        }
    }
    
    // Helper function to get a user's current balance in a trip
    private func getUserBalanceInTrip(_ trip: Trip) -> Double {
        // Find current user's representation in this trip
        let userIds = [currentUser.id]
        let claimedParticipants = trip.participants.filter { $0.claimedByUserId == currentUser.id }
        let userParticipantIds = userIds + claimedParticipants.map { $0.id }
        
        // Calculate balance for all user's identities in this trip
        var balance: Double = 0
        
        for expense in trip.expenses {
            // Get expense amount converted to the trip's base currency
            let expenseCurrency = expense.currencyCode ?? trip.baseCurrencyCode
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            // Check if user paid for this expense
            if userParticipantIds.contains(expense.paidBy.id) {
                // User paid, so they're owed money
                balance += convertedAmount
            }
            
            // Check how much user owes for this expense
            for share in expense.shares {
                if userParticipantIds.contains(share.user.id) {
                    // Convert the share amount to trip's base currency
                    let convertedShareAmount = CurrencyConverterService.shared.convert(
                        amount: share.amount,
                        from: expenseCurrency,
                        to: trip.baseCurrencyCode
                    )
                    
                    // User has a share in this expense, reduce balance
                    balance -= convertedShareAmount
                }
            }
        }
        
        return balance
    }
    
    // MARK: - Balance Calculation
    
    func calculateDebts() -> [Debt] {
        guard let trip = currentTrip else {
            return []
        }
        
        return trip.calculateDebts()
    }
    
    // MARK: - Currency Management
    
    // Update the base currency for the trip
    func updateBaseCurrency(to currencyCode: String) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Update the base currency
        trip.baseCurrencyCode = currencyCode
        
        // Update trip in array locally
        if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[tripIndex] = trip
            currentTrip = trip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error updating base currency: \(error.localizedDescription)"
            }
        }
    }
    
    // Get the current base currency code
    func getBaseCurrencyCode() -> String {
        return currentTrip?.baseCurrencyCode ?? "USD"
    }
    
    // Get the current base currency symbol
    func getBaseCurrencySymbol() -> String {
        return currentTrip?.baseCurrencySymbol ?? "$"
    }
    
    // MARK: - Participant Management
    
    // Add the current user to a trip
    func addCurrentUserToTrip(_ trip: Trip) {
        // Create a copy of the trip to modify
        var updatedTrip = trip
        
        // Check if current user is already a participant
        if updatedTrip.participants.contains(where: { $0.id == currentUser.id }) {
            errorMessage = "You are already a participant in this trip"
            return
        }
        
        // Add current user to trip
        updatedTrip.participants.append(currentUser)
        
        // Update trip in array locally
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = updatedTrip
            currentTrip = updatedTrip
        } else {
            // Trip not in local array yet, add it
            trips.append(updatedTrip)
            currentTrip = updatedTrip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error adding you to trip: \(error.localizedDescription)"
            }
        }
    }
    
    // Add a participant to the current trip
    func addParticipantToCurrentTrip(_ user: User) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Check if user is already a participant
        if trip.participants.contains(where: { $0.id == user.id }) {
            errorMessage = "User is already a participant in this trip"
            return
        }
        
        // Add user to trip
        trip.participants.append(user)
        
        // Update trip in array locally
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error adding participant: \(error.localizedDescription)"
            }
        }
    }
    
    // Add an unclaimed participant (placeholder) to the current trip
    func addUnclaimedParticipantToCurrentTrip(name: String, email: String = "") {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Create unclaimed participant with the current authenticated user as the creator
        let unclaimedParticipant = User.createUnclaimed(name: name, email: email)
        print("Creating unclaimed participant: \(name) with ID: \(unclaimedParticipant.id)")
        
        // Add to trip - updating locally first
        trip.participants.append(unclaimedParticipant)
        
        // Update trip in array locally
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        }
        
        // For unclaimed participants, we need to make sure the current authenticated user
        // is the one making the Firestore update, not the unclaimed participant
        isLoading = true
        
        // Log for debugging
        print("Attempting to save unclaimed participant to Firestore...")
        print("Current authenticated user: \(Auth.auth().currentUser?.uid ?? "none")")
        print("Trip creator ID: \(trip.participants.first?.id ?? "unknown")")
        
        // Save updated trip to Firestore with the current user's auth
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                print("Error adding unclaimed participant: \(error.localizedDescription)")
                self.errorMessage = "Error adding participant: \(error.localizedDescription)"
            } else {
                print("Successfully added unclaimed participant to Firestore")
            }
        }
    }
    
    // Claim a participant
    func claimParticipant(_ participant: User, inTrip trip: Trip) {
        // Find the trip and participant
        guard var updatedTrip = trips.firstIndex(where: { $0.id == trip.id }).map({ trips[$0] }),
              let participantIndex = updatedTrip.participants.firstIndex(where: { $0.id == participant.id }) else {
            errorMessage = "Could not find participant to claim"
            return
        }
        
        // Update participant to be claimed by current user
        var updatedParticipant = participant
        updatedParticipant.isClaimed = true
        updatedParticipant.claimedByUserId = currentUser.id
        
        // Update name and email if the placeholder had empty values
        if updatedParticipant.name.isEmpty {
            updatedParticipant.name = currentUser.name
        }
        if updatedParticipant.email.isEmpty {
            updatedParticipant.email = currentUser.email
        }
        
        // Store the original ID for expense and share updates
        let originalParticipantId = participant.id
        
        // Replace in the participants array
        updatedTrip.participants[participantIndex] = updatedParticipant
        
        // Update all expenses to reflect the claimed participant
        // This is crucial for balance calculation and expense creation
        for expenseIndex in 0..<updatedTrip.expenses.count {
            var expense = updatedTrip.expenses[expenseIndex]
            
            // Update the paidBy field if this participant paid for the expense
            if expense.paidBy.id == originalParticipantId {
                expense.paidBy = updatedParticipant
            }
            
            // Update the user in expense shares
            for shareIndex in 0..<expense.shares.count {
                if expense.shares[shareIndex].user.id == originalParticipantId {
                    var updatedShare = expense.shares[shareIndex]
                    updatedShare.user = updatedParticipant
                    expense.shares[shareIndex] = updatedShare
                }
            }
            
            // Update the expense in the trip
            updatedTrip.expenses[expenseIndex] = expense
        }
        
        // Update trip in array locally
        if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[tripIndex] = updatedTrip
            currentTrip = updatedTrip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error claiming participant: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - User Management
    
    // Find the current user's participant in the trip (handles both direct and claimed participants)
    func findCurrentUserInTrip() -> User? {
        guard let trip = currentTrip else {
            return nil
        }
        
        // First check if the current user is directly in the trip
        if let directUser = trip.participants.first(where: { $0.id == currentUser.id }) {
            return directUser
        }
        
        // Then check if the current user has claimed any participant
        return trip.participants.first(where: { 
            $0.isClaimed && $0.claimedByUserId == currentUser.id 
        })
    }
    
    // Update the current user
    func updateCurrentUser(_ user: User) {
        self.currentUser = user
        
        // Persist user preferences locally first (this always works)
        UserDefaults.standard.set(user.name, forKey: "user_name")
        UserDefaults.standard.set(user.email, forKey: "user_email")
        UserDefaults.standard.set(user.id, forKey: "user_id")
        
        // Then try to update in Firestore if authentication is working
        if Auth.auth().currentUser != nil {
            // Update user in any trips where they are a participant
            for (index, trip) in trips.enumerated() {
                if let participantIndex = trip.participants.firstIndex(where: { $0.id == user.id }) {
                    var updatedTrip = trip
                    updatedTrip.participants[participantIndex] = user
                    trips[index] = updatedTrip
                    
                    // Update currentTrip if it's the one being changed
                    if currentTrip?.id == trip.id {
                        currentTrip = updatedTrip
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
    
    // Load user from persistence or create new
    static func loadOrCreateUser() -> User {
        print("Loading or creating user...")
        
        // Try to get Firebase user ID
        let firebaseUserId = FirebaseService.shared.getCurrentUserId()
        
        if let firebaseUserId = firebaseUserId {
            print("Found Firebase user ID: \(firebaseUserId)")
        } else {
            print("No Firebase user ID found, will try to authenticate later")
        }
        
        // Check if we have saved user info
        if let name = UserDefaults.standard.string(forKey: "user_name"),
           let email = UserDefaults.standard.string(forKey: "user_email"),
           let id = UserDefaults.standard.string(forKey: "user_id"),
           !name.isEmpty {
            print("Found saved user: \(name), \(email)")
            
            // Use existing user but ensure the ID aligns with Firebase if available
            let userId = firebaseUserId ?? id
            let user = User(id: userId, name: name, email: email, profileImage: nil, isClaimed: true)
            
            // If we've updated the user ID, save it back to UserDefaults
            if userId != id {
                print("Updating saved user ID from \(id) to \(userId)")
                UserDefaults.standard.set(userId, forKey: "user_id")
            }
            
            return user
        }
        
        // Create default user with Firebase ID if available
        let userId = firebaseUserId ?? UUID().uuidString
        print("Creating new default user with ID: \(userId)")
        
        // Save this new user to UserDefaults
        let newUser = User(id: userId, name: "You", email: "you@example.com", profileImage: nil, isClaimed: true)
        UserDefaults.standard.set(newUser.name, forKey: "user_name")
        UserDefaults.standard.set(newUser.email, forKey: "user_email")
        UserDefaults.standard.set(newUser.id, forKey: "user_id")
        
        return newUser
    }
    
    // Get a list of unclaimed participants in a trip
    func getUnclaimedParticipants(in trip: Trip) -> [User] {
        // Return all participants that are not claimed and either:
        // 1. Have no email (can be claimed by anyone), OR
        // 2. Have an email that matches the current user's email
        return trip.participants.filter { participant in
            !participant.isClaimed && 
            (participant.email.isEmpty || 
             participant.email.lowercased() == currentUser.email.lowercased())
        }
    }
    
    // MARK: - Auto-join Trip from Deep Link
    
    // Add new method to get previous participants
    func getPreviousParticipants() -> [User] {
        var allParticipants: [User] = []
        var uniqueParticipantIds = Set<String>()
        
        // Collect participants from all trips, excluding the current user
        for trip in trips {
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
    
    /// Automatically join a trip with the given invite code without showing the join sheet
    /// Returns a tuple of (success, errorMessage)
    func autoJoinTrip(withInviteCode code: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        self.errorMessage = nil
        
        // First ensure we have Firebase authentication
        signInAnonymouslyIfNeeded {
            // Check if we already have this trip locally
            if let existingTrip = self.trips.first(where: { $0.inviteCode == code }) {
                // Already a member of this trip
                if existingTrip.participants.contains(where: { $0.id == self.currentUser.id }) {
                    // We're already in this trip - select it and return success
                    self.currentTrip = existingTrip
                    self.isLoading = false
                    completion(true)
                    return
                }
                
                // Check for unclaimed participants that could be claimed
                let unclaimedParticipants = self.getUnclaimedParticipants(in: existingTrip)
                
                if !unclaimedParticipants.isEmpty {
                    // We have unclaimed participants - show the claim view 
                    self.potentialClaimableParticipants = unclaimedParticipants
                    self.showParticipantClaimingView = true
                    self.isLoading = false
                    self.currentTrip = existingTrip
                    // Return false because we need user input for claiming
                    completion(false)
                    return
                }
                
                // No unclaimed participants - add self to the trip locally
                var updatedTrip = existingTrip
                updatedTrip.participants.append(self.currentUser)
                
                // Save the updated trip to Firestore
                FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
                    guard let self = self else { return }
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    if success {
                        if let index = self.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                            self.trips[index] = updatedTrip
                        }
                        self.currentTrip = updatedTrip
                        // Set up the trip listener to keep the trip data in sync
                        self.setupTripListener(for: updatedTrip.id)
                        // Load trips again to ensure we have the latest data
                        self.loadTrips()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
                return
            }
            
            // Fetch trip from Firestore
            FirebaseService.shared.fetchTrip(withInviteCode: code) { [weak self] trip, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error finding trip: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard var trip = trip else {
                    self.errorMessage = "Invalid invite code or trip not found"
                    completion(false)
                    return
                }
                
                // Check if already a participant
                if trip.participants.contains(where: { $0.id == self.currentUser.id }) {
                    // We're already in this trip - select it and return success
                    self.currentTrip = trip
                    
                    // Add trip to local trips array if not already there
                    if !self.trips.contains(where: { $0.id == trip.id }) {
                        self.trips.append(trip)
                    }
                    
                    completion(true)
                    return
                }
                
                // Check for unclaimed participants that could be claimed
                let unclaimedParticipants = self.getUnclaimedParticipants(in: trip)
                
                if !unclaimedParticipants.isEmpty {
                    // We have unclaimed participants - show the claim view 
                    self.potentialClaimableParticipants = unclaimedParticipants
                    self.showParticipantClaimingView = true
                    self.currentTrip = trip
                    
                    // Add trip to local trips array if not already there
                    if !self.trips.contains(where: { $0.id == trip.id }) {
                        self.trips.append(trip)
                    }
                    
                    completion(false)
                    return
                }
                
                // No unclaimed participants - add self to trip
                // Make sure we're using the current Firebase user ID
                if let firebaseUserId = FirebaseService.shared.getCurrentUserId() {
                    // Only update the local user model if the IDs don't match
                    if self.currentUser.id != firebaseUserId {
                        print("Updating user ID from \(self.currentUser.id) to Firebase ID: \(firebaseUserId)")
                        
                        // Create updated user with the Firebase ID
                        var updatedUser = self.currentUser
                        updatedUser.id = firebaseUserId
                        
                        // Update the current user reference
                        self.currentUser = updatedUser
                        
                        // Save the updated user ID to UserDefaults
                        UserDefaults.standard.set(firebaseUserId, forKey: "user_id")
                    }
                }
                trip.participants.append(self.currentUser)
                
                // Save updated trip to Firestore
                FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        self.errorMessage = "Error joining trip: \(error.localizedDescription)"
                        completion(false)
                        return
                    }
                    
                    if success {
                        // Add trip to local trips array if not already there
                        if !self.trips.contains(where: { $0.id == trip.id }) {
                            self.trips.append(trip)
                        }
                        self.currentTrip = trip
                        // Set up the trip listener to keep the trip data in sync
                        self.setupTripListener(for: trip.id)
                        // Load trips again to ensure we have the latest data
                        self.loadTrips()
                        completion(true)
                    } else {
                        completion(false)
                    }
                }
            }
        }
    }
    
    // Check if user can leave a trip (has zero balance)
    func canLeaveTrip(_ trip: Trip) -> Bool {
        let balance = getUserBalanceInTrip(trip)
        return abs(balance) < 0.01 // Using a small epsilon for floating-point comparison
    }
    
    // Get user's balance in a trip with proper formatting
    func getUserBalanceString(_ trip: Trip) -> String {
        let balance = getUserBalanceInTrip(trip)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = trip.baseCurrencySymbol
        return formatter.string(from: NSNumber(value: abs(balance))) ?? "\(trip.baseCurrencySymbol)\(abs(balance))"
    }
    
    // Add a payment between two participants
    func addPaymentToCurrentTrip(title: String, amount: Double, paidBy: User, paidTo: User, currencyCode: String = "USD") {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Make sure both users are valid participants in the trip
        guard let validPaidBy = trip.participants.first(where: { $0.id == paidBy.id }),
              let validPaidTo = trip.participants.first(where: { $0.id == paidTo.id }) else {
            errorMessage = "Invalid participants for payment"
            return
        }
        
        // Create a special payment expense that only involves two people
        // In this expense, one person pays and only the other person has a share
        let share = ExpenseShare(user: validPaidTo, amount: amount, percentage: 100.0)
        
        // Create a payment with special metadata to identify it as a payment
        let paymentExpense = Expense(
            id: UUID().uuidString,
            title: title,
            description: "Payment", // This is a special marker we'll use to identify payments
            amount: amount,
            date: Date(),
            category: .other, // Could create a dedicated payment category if desired
            paidBy: validPaidBy,
            shares: [share],
            currencyCode: currencyCode
        )
        
        // Add expense to trip
        trip.expenses.append(paymentExpense)
        
        // Update trip in array locally
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        }
        
        // Save trip with new payment to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error recording payment: \(error.localizedDescription)"
            }
        }
    }
    
    // Update user in the view model and sync with Firestore
    func updateUser(_ user: User) {
        // Update current user
        currentUser = user
        
        // Update user in any trips where they are a participant
        for (index, trip) in trips.enumerated() {
            if let participantIndex = trip.participants.firstIndex(where: { $0.id == user.id }) {
                var updatedTrip = trip
                updatedTrip.participants[participantIndex] = user
                trips[index] = updatedTrip
                
                // Update currentTrip if it's the one being changed
                if currentTrip?.id == trip.id {
                    currentTrip = updatedTrip
                }
                
                // Save the updated trip to Firestore
                FirebaseService.shared.saveTrip(updatedTrip) { success, error in
                    if !success {
                        print("Warning: Failed to update user in trip \(trip.id): \(error?.localizedDescription ?? "unknown error")")
                    }
                }
            }
        }
    }
    
    func signInAnonymouslyIfNeeded(completion: @escaping () -> Void) {
        // Check if we already have a Firebase user
        if Auth.auth().currentUser != nil {
            print("Already signed in anonymously")
            completion()
            return
        }
        
        // Try to sign in anonymously
        print("No Firebase user, signing in anonymously...")
        FirebaseService.shared.signInAnonymously { success, error in
            if success {
                print("Successfully signed in anonymously")
                completion()
            } else {
                print("Failed to sign in anonymously: \(error?.localizedDescription ?? "unknown error")")
                // Still call completion to let the operation proceed
                // Authentication might still work on a retry
                completion()
            }
        }
    }
}

// Types of expense splits
enum SplitType {
    case equal
    case custom
}
