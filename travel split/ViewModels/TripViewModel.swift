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
        
        // For demo purposes, we'll create a sample trip if none exists
        // In a real app, this would load from Firestore
        if trips.isEmpty {
            let sampleTrip = Trip.create(
                name: "Weekend Getaway",
                description: "A fun weekend with friends",
                creator: currentUser
            )
            trips.append(sampleTrip)
        }
        
        // In a real implementation, we would fetch all trips from Firestore where the current user is a participant
        
        /*
        let db = Firestore.firestore()
        db.collection("trips")
            .whereField("participants", arrayContains: currentUser.id)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "Error loading trips: \(error.localizedDescription)"
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    return
                }
                
                // Parse trips from Firestore
                self.trips = documents.compactMap { document in
                    try? document.data(as: Trip.self)
                }
                
                // Set up listeners for each trip
                for trip in self.trips {
                    self.setupTripListener(for: trip.id)
                }
            }
        */
        
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
        
        // Check if we already have this trip locally
        if let existingTrip = trips.first(where: { $0.inviteCode == code }) {
            // Already a member of this trip
            if existingTrip.participants.contains(where: { $0.id == currentUser.id }) {
                errorMessage = "You are already a participant in this trip"
            } else {
                // Check for unclaimed participants that could be claimed
                let unclaimedParticipants = getUnclaimedParticipants(in: existingTrip)
                
                if !unclaimedParticipants.isEmpty {
                    // We have unclaimed participants - show the claim view instead of auto-joining
                    potentialClaimableParticipants = unclaimedParticipants
                    showParticipantClaimingView = true
                    isLoading = false
                    currentTrip = existingTrip
                    return
                }
                
                // No unclaimed participants - add self to the trip locally
                var updatedTrip = existingTrip
                updatedTrip.participants.append(currentUser)
                
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
            trip.participants.append(self.currentUser)
            
            // Save updated trip to Firestore
            FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = "Error joining trip: \(error.localizedDescription)"
                    return
                }
                
                if success {
                    self.trips.append(trip)
                    self.currentTrip = trip
                    self.setupTripListener(for: trip.id)
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
    
    // Delete a trip by ID
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
            return User(id: userId, name: name, email: email, profileImage: nil, isClaimed: true)
        }
        
        // Create default user with Firebase ID if available
        let userId = firebaseUserId ?? UUID().uuidString
        print("Creating new default user with ID: \(userId)")
        return User.create(name: "You", email: "you@example.com")
    }
    
    // Get a list of unclaimed participants in a trip
    func getUnclaimedParticipants(in trip: Trip) -> [User] {
        // Return all participants that are not claimed
        return trip.participants.filter { !$0.isClaimed }
    }
}

// Types of expense splits
enum SplitType {
    case equal
    case custom
}
