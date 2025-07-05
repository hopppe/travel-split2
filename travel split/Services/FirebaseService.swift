// FirebaseService.swift
// EquiSplit
//
// Created for firebase integration and cloud data synchronization

import SwiftUI
// Uncomment these imports since we're now using Firebase
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth  // Add Firebase Auth import
import TravelSplitModels

// MARK: - Firebase Service
public class FirebaseService {
    public static let shared = FirebaseService()
    
    // Add a property to track authentication state
    @Published public var isAuthenticated = false
    private var userId: String?
    
    // App bundle identifiers for deep linking
    private let iosBundleId = "com.ingenuitylabsllc.freesplitapp"
    private let androidPackageName = "com.ingenuitylabsllc.freesplitapp" // Update this if you have an Android version
    
    private init() {
        // Firebase is now configured in AppDelegate
        print("Firebase Service initialized")
        
        // Defer checking for current user to make sure Firebase is configured
        DispatchQueue.main.async {
            // Check if user is already authenticated
            if let user = Auth.auth().currentUser {
                self.userId = user.uid
                self.isAuthenticated = true
                print("User is already authenticated with ID: \(user.uid)")
            }
        }
    }
    
    // MARK: - Authentication
    
    // Sign in anonymously
    public func signInAnonymously(completion: @escaping (Bool, Error?) -> Void) {
        // Check if anonymous auth is allowed, but log the value first for debugging
        let isAnonymousAuthAllowed = UserDefaults.standard.bool(forKey: "allowAnonymousAuth")
        print("Anonymous auth allowed: \(isAnonymousAuthAllowed)")
        
        // Temporarily force-enable anonymous auth to fix the regression
        UserDefaults.standard.set(true, forKey: "allowAnonymousAuth")
        
        // Check if already signed in
        if let currentUser = Auth.auth().currentUser {
            print("User already authenticated with ID: \(currentUser.uid)")
            self.isAuthenticated = true
            completion(true, nil)
            return
        }
        
        // Get the stored user ID from UserDefaults for potential migration
        let storedUserId = UserDefaults.standard.string(forKey: "user_id")
        print("Stored user ID from UserDefaults: \(storedUserId ?? "none")")
        
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Error signing in anonymously: \(error.localizedDescription)")
                self.isAuthenticated = false
                completion(false, error)
                return
            }
            
            guard let authResult = authResult else {
                print("Error: No auth result returned")
                self.isAuthenticated = false
                completion(false, NSError(domain: "FirebaseService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No auth result returned"]))
                return
            }
            
            let firebaseUserId = authResult.user.uid
            print("Successfully signed in anonymously with Firebase ID: \(firebaseUserId)")
            
            self.isAuthenticated = true
            
            // Handle migration if we have a different stored user ID
            if let storedId = storedUserId, storedId != firebaseUserId, !storedId.isEmpty, !storedId.contains("-") {
                // Only migrate if the stored ID appears to be a valid Firebase ID (not a UUID)
                print("Migrating user data from \(storedId) to \(firebaseUserId)")
                
                self.migrateUserData(fromId: storedId, toId: firebaseUserId) { success in
                    if success {
                        print("User data migration completed successfully")
                    } else {
                        print("User data migration failed or partially completed")
                    }
                    completion(true, nil)
                }
            } else {
                // No migration needed
                completion(true, nil)
            }
        }
    }
    
    // Get current Firebase user ID
    public func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // Get current Firebase user
    public func getCurrentUser() -> FirebaseAuth.User? {
        return Auth.auth().currentUser
    }
    
    // MARK: - Firestore Integration
    
    // Save a trip to Firestore
    public func saveTrip(_ trip: TravelSplitModels.Trip, completion: @escaping (Bool, Error?) -> Void) {
        print("Starting to save trip to Firestore: \(trip.id)")
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        // Check if user is authenticated before saving
        if Auth.auth().currentUser == nil {
            print("No authenticated user found, but NOT automatically creating anonymous user")
            // We'll still try to save with the trip's creator ID for local use
            completion(false, NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to save to Firestore"]))
            return
        }
        
        // User is authenticated
        let currentUser = Auth.auth().currentUser!
        print("Saving trip with authenticated user: \(currentUser.uid)")
        print("Trip has \(trip.participants.count) participants")
        
        // Print participant IDs for debugging
        for (index, participant) in trip.participants.enumerated() {
            print("Participant \(index): id=\(participant.id), name=\(participant.name), isClaimed=\(participant.isClaimed)")
        }
        
        do {
            try db.collection("trips").document(trip.id).setData(from: trip) { error in
                if let error = error {
                    print("Error saving trip: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("Trip successfully saved to Firestore!")
                    completion(true, nil)
                }
            }
        } catch {
            print("Error encoding trip: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    // Fetch all trips where the user is a participant
    public func fetchTripsForUser(userId: String, completion: @escaping ([TravelSplitModels.Trip]?, Error?) -> Void) {
        // Check if user is authenticated before fetching
        if Auth.auth().currentUser == nil {
            print("No authenticated user found for fetching trips")
            // Return empty array for offline mode - don't automatically create anonymous user
            completion([], NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to fetch from Firestore"]))
            return
        }
        
        print("Fetching trips for user: \(userId)")
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        // Query for all trips - we'll filter for user membership client-side
        // This approach is necessary because Firestore doesn't support querying on nested fields in arrays
        db.collection("trips")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching trips: \(error.localizedDescription)")
                    completion(nil as [TravelSplitModels.Trip]?, error)
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("No trips found")
                    completion([], nil)
                    return
                }
                
                var trips: [TravelSplitModels.Trip] = []
                
                for document in documents {
                    do {
                        let trip = try document.data(as: TravelSplitModels.Trip.self)
                        
                        // Check if the user is a participant in this trip
                        let isParticipant = trip.participants.contains { participant in
                            // Check for direct ID match or claimed match
                            return participant.id == userId || participant.claimedByUserId == userId
                        }
                        
                        if isParticipant {
                            print("User is a participant in trip: \(trip.id), \(trip.name)")
                            trips.append(trip)
                        } else {
                            // Print all participant IDs for debugging
                            print("Trip: \(trip.id), \(trip.name) - User is NOT a participant. Checking participants:")
                            for (index, p) in trip.participants.enumerated() {
                                print("  \(index): \(p.name) (ID: \(p.id), isClaimed: \(p.isClaimed), claimedByUserId: \(p.claimedByUserId ?? "none"))")
                            }
                        }
                    } catch {
                        print("Error decoding trip \(document.documentID): \(error.localizedDescription)")
                        // Continue loading other trips even if one fails
                    }
                }
                
                print("Found \(trips.count) trips where user is a participant")
                completion(trips, nil)
            }
    }
    
    // Fetch a trip from Firestore by invite code
    public func fetchTrip(withInviteCode code: String, completion: @escaping (TravelSplitModels.Trip?, Error?) -> Void) {
        // Check if user is authenticated before fetching
        if Auth.auth().currentUser == nil {
            print("No authenticated user found for fetching trip by invite code")
            // Return error - don't automatically create anonymous user
            completion(nil as TravelSplitModels.Trip?, NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to fetch trip by invite code"]))
            return
        }
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        db.collection("trips")
            .whereField("inviteCode", isEqualTo: code)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching trip: \(error.localizedDescription)")
                    completion(nil as TravelSplitModels.Trip?, error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(nil, NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip not found"]))
                    return
                }
                
                do {
                    let trip = try document.data(as: TravelSplitModels.Trip.self)
                    completion(trip, nil)
                } catch {
                    print("Error decoding trip: \(error.localizedDescription)")
                    completion(nil as TravelSplitModels.Trip?, error)
                }
            }
    }
    
    // Fetch a trip from Firestore by ID
    public func fetchTrip(withId id: String, completion: @escaping (TravelSplitModels.Trip?, Error?) -> Void) {
        // Check if user is authenticated before fetching
        if Auth.auth().currentUser == nil {
            print("No authenticated user found for fetching trip by ID")
            // Return error - don't automatically create anonymous user
            completion(nil as TravelSplitModels.Trip?, NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required to fetch trip by ID"]))
            return
        }
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        db.collection("trips").document(id).getDocument { documentSnapshot, error in
            if let error = error {
                print("Error fetching trip: \(error.localizedDescription)")
                completion(nil as TravelSplitModels.Trip?, error)
                return
            }
            
            guard let document = documentSnapshot, document.exists else {
                completion(nil, NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip not found"]))
                return
            }
            
            do {
                let trip = try document.data(as: TravelSplitModels.Trip.self)
                completion(trip, nil)
            } catch {
                print("Error decoding trip: \(error.localizedDescription)")
                completion(nil as TravelSplitModels.Trip?, error)
            }
        }
    }
    
    // Listen for real-time updates to a trip
    public func listenForTripUpdates(tripId: String, completion: @escaping (TravelSplitModels.Trip?, Error?) -> Void) -> Any? {
        // Check if user is authenticated before listening
        if Auth.auth().currentUser == nil {
            print("No authenticated user found for listening to trip updates")
            completion(nil as TravelSplitModels.Trip?, NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required for real-time updates"]))
            return nil
        }
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        let listener = db.collection("trips").document(tripId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil as TravelSplitModels.Trip?, error)
                    return
                }
                
                guard document.exists else {
                    completion(nil, NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip no longer exists"]))
                    return
                }
                
                do {
                    let trip = try document.data(as: TravelSplitModels.Trip.self)
                    completion(trip, nil)
                } catch {
                    print("Error decoding trip: \(error.localizedDescription)")
                    completion(nil as TravelSplitModels.Trip?, error)
                }
            }
            
        return listener
    }
    
    // Stop listening for updates
    public func stopListening(listener: Any) {
        if let listener = listener as? ListenerRegistration {
            listener.remove()
        }
    }
    
    // MARK: - Deep Linking
    
    /// Create a Universal Link for sharing that works with app installation detection
    public func createUniversalLink(inviteCode: String) -> URL {
        // Use Universal Link that will redirect to App Store if app not installed
        let universalLink = "https://equisplit.ingenuitylabs.net/join/\(inviteCode)"
        print("Generated Universal Link: \(universalLink)")
        return URL(string: universalLink)!
    }
    
    /// Create a direct app URL scheme for fallback/testing
    public func createDirectAppLink(inviteCode: String) -> URL {
        let directURL = "travelsplit://join?code=\(inviteCode)"
        print("Direct app URL for fallback: \(directURL)")
        return URL(string: directURL)!
    }
    
    // Generate a shareable message for the invite code
    public func generateShareMessage(inviteCode: String, tripName: String) -> String {
        // Use Universal Link for better user experience
        let universalLink = createUniversalLink(inviteCode: inviteCode)
        
        return "Join my group \"\(tripName)\" in EquiSplit!\n\n\(universalLink)"
    }
    
    // Generate a unique ID for an unclaimed participant
    // This helps tie the unclaimed participant to the authenticated user who created it
    public func generateUnclaimedParticipantId(name: String) -> String {
        // Format: "unclaimed_{auth_user_id}_{random_uuid}_{sanitized_name}"
        let authUserId = Auth.auth().currentUser?.uid ?? "no_auth"
        let randomPart = UUID().uuidString.prefix(8)
        // Sanitize name to remove spaces and special characters, lowercase
        let sanitizedName = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: String.CompareOptions.regularExpression)
        
        return "unclaimed_\(authUserId)_\(randomPart)_\(sanitizedName)"
    }
    
    // MARK: - Trip Operations
    
    /// Delete a trip from Firestore
    public func deleteTrip(withId id: String, completion: @escaping (Error?) -> Void) {
        guard isAuthenticated else {
            completion(NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]))
            return
        }
        
        // Delete the trip document
        let tripRef = Firestore.firestore().collection("trips").document(id)
        tripRef.delete { error in
            if let error = error {
                print("Error deleting trip: \(error)")
                completion(error)
                return
            }
            
            print("Trip successfully deleted")
            completion(nil)
        }
    }
    
    // MARK: - Expense Operations
    
    // MARK: - User Data Migration
    
    // Transfer user data from one user ID to another (e.g., from anonymous to signed-in user)
    public func migrateUserData(fromId: String, toId: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        let batch = db.batch()
        
        // Update trips where the user is a participant
        db.collection("trips").whereField("participants", arrayContains: fromId).getDocuments { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error fetching trips for migration: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            for document in documents {
                let tripRef = db.collection("trips").document(document.documentID)
                
                // Get current participants array
                if var participants = document.data()["participants"] as? [String] {
                    // Replace old ID with new ID if it exists
                    if let index = participants.firstIndex(of: fromId) {
                        participants[index] = toId
                        batch.updateData(["participants": participants], forDocument: tripRef)
                    }
                }
                
                // Update expenses in this trip
                db.collection("trips").document(document.documentID).collection("expenses")
                    .whereField("paidBy", isEqualTo: fromId).getDocuments { expSnapshot, expError in
                        guard let expDocuments = expSnapshot?.documents, expError == nil else {
                            print("Error fetching expenses for migration: \(expError?.localizedDescription ?? "Unknown error")")
                            return
                        }
                        
                        for expDoc in expDocuments {
                            let expRef = tripRef.collection("expenses").document(expDoc.documentID)
                            batch.updateData(["paidBy": toId], forDocument: expRef)
                        }
                        
                        // Commit all the changes as a batch
                        batch.commit { batchError in
                            if let batchError = batchError {
                                print("Error committing migration batch: \(batchError.localizedDescription)")
                                completion(false)
                            } else {
                                print("Migration batch committed successfully")
                                completion(true)
                            }
                        }
                    }
            }
            
            // If no documents were found, consider it a success
            if documents.isEmpty {
                completion(true)
            }
        }
    }
}

// MARK: - Helper Extensions
extension URL {
    // Helper to safely get query parameters from URLs
    var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems, !queryItems.isEmpty else {
            return nil
        }
        
        var parameters = [String: String]()
        for queryItem in queryItems {
            parameters[queryItem.name] = queryItem.value
        }
        
        return parameters
    }
} 