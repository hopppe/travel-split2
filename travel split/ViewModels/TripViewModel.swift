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

// Main ViewModel to handle Trip operations 
// Acts as a coordinator for the specialized components
class TripViewModel: ObservableObject {
    // MARK: - Published Properties
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
    var cancellables = Set<AnyCancellable>()
    
    // Component managers
    private lazy var expenseManager = TripExpenseManager(tripViewModel: self)
    private lazy var participantManager = TripParticipantManager(tripViewModel: self)
    private lazy var balanceCalculator = TripBalanceCalculator(tripViewModel: self)
    lazy var userManager = TripUserManager(tripViewModel: self)
    private lazy var joinService: TripJoinService = {
        return TripJoinService(
            tripViewModel: self,
            userManager: userManager,
            participantManager: participantManager
        )
    }()
    
    // Initialize with the current user
    init(currentUser: User) {
        self.currentUser = currentUser
        loadTrips()
    }
    
    // MARK: - Trip Management
    
    func loadTrips() {
        isLoading = true
        
        // Sync user data from Firebase if available
        syncUserFromFirebase()
        
        // Ensure user ID consistency before loading trips
        userManager.ensureUserIdConsistency()
        
        // Get current Firebase user ID
        guard let userId = FirebaseService.shared.getCurrentUserId() else {
            print("No authenticated user ID available, can't load trips")
            isLoading = false
            return
        }
        
        print("Loading trips for user ID: \(userId)")
        
        // Fetch trips where the current user is a participant
        FirebaseService.shared.fetchTripsForUser(userId: userId) { [weak self] fetchedTrips, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error fetching trips: \(error.localizedDescription)")
                self.errorMessage = "Error loading trips: \(error.localizedDescription)"
                self.isLoading = false
                return
            }
            
            if let fetchedTrips = fetchedTrips, !fetchedTrips.isEmpty {
                print("Loaded \(fetchedTrips.count) trips from Firestore")
                self.trips = fetchedTrips
                
                // Set up listeners for all fetched trips
                for trip in fetchedTrips {
                    self.setupTripListener(for: trip.id)
                }
            } else {
                print("No trips found for user")
                self.trips = []
            }
            
            self.isLoading = false
        }
    }
    
    // Sync user data from Firebase
    private func syncUserFromFirebase() {
        if let firebaseUser = Auth.auth().currentUser {
            var updatedUser = currentUser
            
            // Update the user ID to match Firebase
            updatedUser.id = firebaseUser.uid
            
            // Update the name if we have a display name
            if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                updatedUser.name = displayName
            }
            
            // Update the email if we have one
            if let email = firebaseUser.email, !email.isEmpty {
                updatedUser.email = email
            }
            
            // Update the current user
            currentUser = updatedUser
            
            // Save to UserDefaults
            UserDefaults.standard.set(updatedUser.id, forKey: "user_id")
            UserDefaults.standard.set(updatedUser.name, forKey: "user_name")
            UserDefaults.standard.set(updatedUser.email, forKey: "user_email")
        }
    }
    
    // Set up a real-time listener for trip updates
    func setupTripListener(for tripId: String) {
        print("Setting up listener for trip: \(tripId)")
        
        // Remove any existing listener
        if let listener = tripListeners[tripId] {
            print("Removing existing listener for trip: \(tripId)")
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
                print("Received update for trip: \(updatedTrip.id) with \(updatedTrip.participants.count) participants")
                
                // Make sure current user is still in the trip participants
                let currentUserId = self.currentUser.id
                let isStillParticipant = updatedTrip.participants.contains { $0.id == currentUserId }
                
                if !isStillParticipant {
                    print("⚠️ Warning: Current user no longer in trip participants!")
                    // This is a critical issue - log participants for debugging
                    for (index, participant) in updatedTrip.participants.enumerated() {
                        print("Participant \(index): id=\(participant.id), name=\(participant.name)")
                    }
                }
                
                // Update the trip in our array
                if let index = self.trips.firstIndex(where: { $0.id == updatedTrip.id }) {
                    self.trips[index] = updatedTrip
                    
                    // If this is the current trip, update it
                    if self.currentTrip?.id == updatedTrip.id {
                        self.currentTrip = updatedTrip
                    }
                } else {
                    // This is a new trip, add it
                    print("Adding new trip from listener update: \(updatedTrip.id)")
                    self.trips.append(updatedTrip)
                }
            }
        }
        
        if let listener = listener {
            print("Successfully set up listener for trip: \(tripId)")
            tripListeners[tripId] = listener
        } else {
            print("Failed to set up listener for trip: \(tripId)")
        }
    }
    
    // Create a new trip and save to Firestore
    func createNewTrip(name: String, description: String, initialParticipants: [User] = []) {
        isLoading = true
        
        // Ensure user ID consistency before creating trip
        userManager.ensureUserIdConsistency()
        
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
    
    // Internal helper to update a trip consistently
    func updateTrip(_ trip: Trip) {
        // Update trip in array locally
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        } else if currentTrip?.id == trip.id {
            // If this is a current trip not in the trips array yet
            trips.append(trip)
            currentTrip = trip
        }
        
        // Save updated trip to Firestore
        isLoading = true
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            self.isLoading = false
            
            if let error = error {
                self.errorMessage = "Error updating trip: \(error.localizedDescription)"
            }
        }
    }
    
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
    
    // Leave a trip - Remove the current user from participants
    func leaveTrip(trip: Trip) {
        isLoading = true
        
        // Check if the user has any outstanding balances
        let canLeave = balanceCalculator.canLeaveTrip(trip)
        
        // If balance is not zero, user cannot leave
        if !canLeave {
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
    
    // MARK: - Delegate methods to component managers
    
    // MARK: - Expense Management Delegation
    
    func addExpenseToCurrentTrip(title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD") {
        expenseManager.addExpense(title: title, amount: amount, paidBy: paidBy, splitType: splitType, customShares: customShares, category: category, currencyCode: currencyCode)
    }
    
    func updateExpense(id: String, title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD") {
        expenseManager.updateExpense(id: id, title: title, amount: amount, paidBy: paidBy, splitType: splitType, customShares: customShares, category: category, currencyCode: currencyCode)
    }
    
    func deleteExpense(withId id: String) {
        expenseManager.deleteExpense(withId: id)
    }
    
    func addPaymentToCurrentTrip(title: String, amount: Double, paidBy: User, paidTo: User, currencyCode: String = "USD") {
        expenseManager.addPayment(title: title, amount: amount, paidBy: paidBy, paidTo: paidTo, currencyCode: currencyCode)
    }
    
    // MARK: - Participant Management Delegation
    
    func addCurrentUserToTrip(_ trip: Trip) {
        participantManager.addCurrentUserToTrip(trip)
    }
    
    func addParticipantToCurrentTrip(_ user: User) {
        participantManager.addParticipant(user)
    }
    
    func addUnclaimedParticipantToCurrentTrip(name: String, email: String = "") {
        participantManager.addUnclaimedParticipant(name: name, email: email)
    }
    
    func removeParticipantFromCurrentTrip(_ participant: User) -> Bool {
        return participantManager.removeParticipant(participant)
    }
    
    func claimParticipant(_ participant: User) {
        participantManager.claimParticipant(participant)
    }
    
    func findCurrentUserInTrip() -> User? {
        return participantManager.findCurrentUserInTrip()
    }
    
    func getUnclaimedParticipants(in trip: Trip) -> [User] {
        return participantManager.getUnclaimedParticipants(in: trip)
    }
    
    func getPreviousParticipants() -> [User] {
        return participantManager.getPreviousParticipants()
    }
    
    // MARK: - Balance Calculation Delegation
    
    func calculateDebts() -> [Debt] {
        return balanceCalculator.calculateDebts()
    }
    
    func getUserBalanceInTrip(_ trip: Trip) -> Double {
        return balanceCalculator.getUserBalance(in: trip)
    }
    
    func canLeaveTrip(_ trip: Trip) -> Bool {
        return balanceCalculator.canLeaveTrip(trip)
    }
    
    func getUserBalanceString(_ trip: Trip) -> String {
        return balanceCalculator.getUserBalanceString(trip)
    }
    
    func updateBaseCurrency(to currencyCode: String) {
        balanceCalculator.updateBaseCurrency(to: currencyCode)
    }
    
    func getBaseCurrencyCode() -> String {
        return balanceCalculator.getBaseCurrencyCode()
    }
    
    func getBaseCurrencySymbol() -> String {
        return balanceCalculator.getBaseCurrencySymbol()
    }
    
    // MARK: - User Management
    
    func updateCurrentUser(_ user: User) {
        currentUser = user
    }
    
    // Reset the view model state after sign out
    func reset() {
        // Clear trips
        trips = []
        currentTrip = nil
        
        // Remove all listeners
        for (tripId, listener) in tripListeners {
            print("Removing listener for trip: \(tripId)")
            FirebaseService.shared.stopListening(listener: listener)
        }
        tripListeners.removeAll()
        
        // Reset any error state
        errorMessage = nil
        
        // Reset the participant claiming state
        potentialClaimableParticipants = []
        showParticipantClaimingView = false
        
        // Create a minimal placeholder user
        currentUser = User(id: UUID().uuidString, name: "You", email: "", profileImage: nil, isClaimed: true)
        
        // Force show welcome screen by setting hasCompletedSetup to false
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
    }
    
    static func loadOrCreateUser() -> User {
        return TripUserManager.loadOrCreateUser()
    }
    
    // MARK: - Trip Joining & Sharing Delegation
    
    func generateShareLink() -> String {
        return joinService.generateShareLink()
    }
    
    func joinTrip(withInviteCode code: String, completion: ((Bool) -> Void)? = nil) {
        joinService.joinTrip(withInviteCode: code, completion: completion)
    }
    
    func autoJoinTrip(withInviteCode code: String, completion: @escaping (Bool) -> Void) {
        joinService.autoJoinTrip(withInviteCode: code, completion: completion)
    }
    
    // MARK: - Debugging
    
    // Print debug information about the participant claiming state
    func logParticipantClaimingState() {
        print("\n--- PARTICIPANT CLAIMING STATE ---")
        print("showParticipantClaimingView: \(showParticipantClaimingView)")
        print("potentialClaimableParticipants: \(potentialClaimableParticipants.count)")
        
        for (index, participant) in potentialClaimableParticipants.enumerated() {
            print("  [\(index)] id=\(participant.id), name=\(participant.name), email=\(participant.email), isClaimed=\(participant.isClaimed)")
        }
        
        if let trip = currentTrip {
            print("Current trip: \(trip.id), \(trip.name)")
            print("Trip participants: \(trip.participants.count)")
            for (index, participant) in trip.participants.enumerated() {
                print("  [\(index)] id=\(participant.id), name=\(participant.name), isClaimed=\(participant.isClaimed)")
            }
        } else {
            print("No current trip set")
        }
        print("-------------------------------\n")
    }
}

// Types of expense splits
enum SplitType {
    case equal
    case custom
}
