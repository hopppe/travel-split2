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
    
    // New property to track trips that need to be synced
    @Published var pendingSync: [String: Trip] = [:]
    
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
    init(currentUser: User, trips: [Trip] = []) {
        self.currentUser = currentUser
        self.trips = trips
        
        // Note: We don't need to initialize component managers here
        // since they are already lazily initialized as properties
        
        // Subscribe to network connectivity changes
        NetworkMonitor.shared.connectivityChangedPublisher
            .sink { [weak self] isConnected in
                guard let self = self else { return }
                
                if isConnected {
                    print("Internet connection restored, syncing pending trips")
                    // Try to sync any pending trips when back online
                    self.syncPendingTrips()
                } else {
                    print("Internet connection lost, will queue operations for later sync")
                }
            }
            .store(in: &cancellables)
        
        // Load trips after everything is set up
        loadTrips()
    }
    
    // MARK: - Trip Management
    
    // Force refresh all trips from Firestore
    func refreshTrips() {
        print("Force refreshing all trips from Firestore")
        loadTrips()
    }
    
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
                
                // If we're offline, it's not a critical error, just show the cached data
                if !NetworkMonitor.shared.isConnected {
                    print("Working in offline mode with cached trips")
                    // Remove error message for offline mode
                    self.errorMessage = nil
                }
                
                self.isLoading = false
                return
            }
            
            guard let fetchedTrips = fetchedTrips else {
                self.errorMessage = "Error loading trips: No data returned"
                self.isLoading = false
                return
            }
            
            print("Successfully loaded \(fetchedTrips.count) trips for user")
            
            // Replace local trips array with fetched trips
            self.trips = fetchedTrips
            
            // Set up listeners for each trip
            for trip in fetchedTrips {
                self.setupTripListener(for: trip.id)
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
        
        // Add trip to local state immediately
        self.trips.append(newTrip)
        self.currentTrip = newTrip
        self.isLoading = false
        
        // Add to pending sync dictionary
        pendingSync[newTrip.id] = newTrip
        
        // Try to save to Firestore
        syncTripToFirebase(newTrip)
    }
    
    // New method to sync a trip to Firebase
    private func syncTripToFirebase(_ trip: Trip) {
        FirebaseService.shared.saveTrip(trip) { [weak self] success, error in
            guard let self = self else { return }
            
            if success {
                print("Trip successfully synced to Firestore: \(trip.id)")
                // Remove from pending sync
                self.pendingSync.removeValue(forKey: trip.id)
                
                // Set up real-time listener
                self.setupTripListener(for: trip.id)
            } else {
                print("Failed to sync trip to Firestore: \(error?.localizedDescription ?? "Unknown error")")
                // Keep in pending sync dictionary for later retry
                self.pendingSync[trip.id] = trip
            }
        }
    }
    
    // New method to try syncing any pending trips
    func syncPendingTrips() {
        guard !pendingSync.isEmpty else { return }
        
        print("Attempting to sync \(pendingSync.count) pending trips")
        
        // Create a copy to iterate over while potentially modifying the original
        let tripsToSync = pendingSync
        
        for (_, trip) in tripsToSync {
            syncTripToFirebase(trip)
        }
    }
    
    func selectTrip(_ trip: Trip) {
        currentTrip = trip
    }
    
    // Refresh the current trip data from Firebase
    func refreshCurrentTrip(completion: ((Bool) -> Void)? = nil) {
        guard let trip = currentTrip else {
            print("No current trip to refresh")
            completion?(false)
            return
        }
        
        print("TRIP REFRESH: Starting refresh for trip \(trip.name) (ID: \(trip.id)) with \(trip.expenses.count) expenses")
        isLoading = true
        
        // Fetch the latest trip data from Firebase
        FirebaseService.shared.fetchTrip(withId: trip.id) { [weak self] fetchedTrip, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    print("TRIP REFRESH ERROR: \(error.localizedDescription)")
                    self.errorMessage = "Error refreshing data: \(error.localizedDescription)"
                    completion?(false)
                    return
                }
                
                if let fetchedTrip = fetchedTrip {
                    print("TRIP REFRESH SUCCESS: Trip \(fetchedTrip.name) refreshed with \(fetchedTrip.expenses.count) expenses")
                    
                    // Update trip in local array
                    if let index = self.trips.firstIndex(where: { $0.id == trip.id }) {
                        self.trips[index] = fetchedTrip
                    } else {
                        self.trips.append(fetchedTrip)
                    }
                    
                    // Update current trip
                    self.currentTrip = fetchedTrip
                    
                    completion?(true)
                } else {
                    print("TRIP REFRESH ERROR: Trip not found on server")
                    self.errorMessage = "Trip not found on server"
                    completion?(false)
                }
            }
        }
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
        
        // Add to pending sync
        pendingSync[trip.id] = trip
        
        // Try to save to Firestore
        isLoading = true
        syncTripToFirebase(trip)
        isLoading = false
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
        print(">>> LEAVE TRIP: Starting leave trip process for trip: \(trip.name) (ID: \(trip.id))")
        isLoading = true
        
        // Check if the user has any outstanding balances
        let canLeave = balanceCalculator.canLeaveTrip(trip)
        print(">>> LEAVE TRIP: Can user leave? \(canLeave)")
        
        // If balance is not zero, user cannot leave
        if !canLeave {
            isLoading = false
            errorMessage = "You cannot leave the group until your balance is zero. Please settle all debts first."
            print(">>> LEAVE TRIP: Cannot leave - user has outstanding balance")
            return
        }
        
        // First remove the trip listener to prevent it from re-adding the trip
        if let listener = tripListeners[trip.id] {
            print(">>> LEAVE TRIP: Removing listener for trip: \(trip.id)")
            FirebaseService.shared.stopListening(listener: listener)
            tripListeners.removeValue(forKey: trip.id)
        }
        
        // Create a copy of the trip without the current user
        var updatedTrip = trip
        
        print(">>> LEAVE TRIP: Current user ID: \(currentUser.id)")
        print(">>> LEAVE TRIP: Original participants count: \(trip.participants.count)")
        
        // Remove the current user from participants
        // We need to check for both direct ID match and claimed participant match
        updatedTrip.participants.removeAll(where: { participant in
            let removed = participant.id == currentUser.id || participant.claimedByUserId == currentUser.id
            if removed {
                print(">>> LEAVE TRIP: Removing participant: \(participant.name) (ID: \(participant.id), claimed by: \(participant.claimedByUserId ?? "none"))")
            }
            return removed
        })
        
        print(">>> LEAVE TRIP: Updated participants count: \(updatedTrip.participants.count)")
        
        // If this results in an empty trip, we should delete the trip
        if updatedTrip.participants.isEmpty {
            // Delete the trip entirely
            print(">>> LEAVE TRIP: Trip is now empty, deleting trip")
            deleteTrip(withId: trip.id)
            isLoading = false
            return
        }
        
        // Update local array first
        // Remove the trip from our local trips array since we're no longer in it
        let originalTripsCount = self.trips.count
        self.trips.removeAll(where: { $0.id == trip.id })
        print(">>> LEAVE TRIP: Removed trip from local array. Before: \(originalTripsCount), After: \(self.trips.count)")
        
        // Also remove the trip from pendingSync if it's there
        pendingSync.removeValue(forKey: trip.id)
        
        // Clear current trip if it was the one we left
        if currentTrip?.id == trip.id {
            print(">>> LEAVE TRIP: Clearing current trip as it was the one we left")
            currentTrip = nil
        }
        
        // Save the updated trip to Firestore (with the user removed)
        print(">>> LEAVE TRIP: Saving updated trip to Firestore")
        FirebaseService.shared.saveTrip(updatedTrip) { [weak self] success, error in
            guard let self = self else { 
                print(">>> LEAVE TRIP: Self is nil in completion handler")
                return 
            }
            self.isLoading = false
            
            if let error = error {
                print(">>> LEAVE TRIP ERROR: \(error.localizedDescription)")
                self.errorMessage = "Error leaving trip: \(error.localizedDescription)"
                
                // Since we already removed the listener, we don't need to worry about the trip being re-added automatically.
                // However, we should manually add it back in case of error
                if !self.trips.contains(where: { $0.id == trip.id }) {
                    print(">>> LEAVE TRIP: Adding trip back to local array due to error")
                    self.trips.append(trip)
                    
                    // Re-establish the listener
                    self.setupTripListener(for: trip.id)
                }
            } else {
                print(">>> LEAVE TRIP SUCCESS: Successfully left trip: \(trip.name)")
            }
        }
    }
    
    // MARK: - Delegate methods to component managers
    
    // MARK: - Expense Management Delegation
    
    func addExpenseToCurrentTrip(title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD", date: Date = Date()) {
        expenseManager.addExpense(title: title, amount: amount, paidBy: paidBy, splitType: splitType, customShares: customShares, category: category, currencyCode: currencyCode, date: date)
    }
    
    func updateExpense(id: String, title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other, currencyCode: String = "USD", date: Date = Date()) {
        expenseManager.updateExpense(id: id, title: title, amount: amount, paidBy: paidBy, splitType: splitType, customShares: customShares, category: category, currencyCode: currencyCode, date: date)
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
    
    func canRemoveParticipant(_ participant: User) -> Bool {
        // Can't remove self
        if participant.id == currentUser.id || participant.claimedByUserId == currentUser.id {
            return false
        }
        
        // Need a current trip
        guard let trip = currentTrip else {
            return false
        }
        
        // Check for balance
        return balanceCalculator.isParticipantBalanceZero(participant, in: trip)
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
    
    func getPreviousParticipants(excludingParticipantsFrom trip: Trip? = nil) -> [User] {
        return participantManager.getPreviousParticipants(excludingParticipantsFrom: trip)
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
