// FirebaseService.swift
// travel split
//
// Created for firebase integration and cloud data synchronization

import SwiftUI
// Uncomment these imports since we're now using Firebase
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth  // Add Firebase Auth import

// MARK: - Firebase Service
class FirebaseService {
    static let shared = FirebaseService()
    
    // Add a property to track authentication state
    @Published var isAuthenticated = false
    private var userId: String?
    
    private init() {
        // Firebase is now configured in AppDelegate
        print("Firebase Service initialized")
        
        // Check if user is already authenticated
        if let user = Auth.auth().currentUser {
            self.userId = user.uid
            self.isAuthenticated = true
            print("User is already authenticated with ID: \(user.uid)")
        }
    }
    
    // MARK: - Authentication
    
    // Sign in anonymously
    func signInAnonymously(completion: @escaping (Bool, Error?) -> Void) {
        print("Attempting anonymous sign in...")
        
        // Check if Anonymous auth is enabled in the Firebase console
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                // Get more detailed error info
                let errorCode = (error as NSError).code
                let errorMessage = error.localizedDescription
                let errorUserInfo = (error as NSError).userInfo
                
                print("Error signing in anonymously: \(errorMessage)")
                print("Error code: \(errorCode)")
                print("Error details: \(errorUserInfo)")
                
                // Check for specific error conditions
                if errorCode == AuthErrorCode.operationNotAllowed.rawValue {
                    print("CRITICAL: Anonymous authentication is not enabled in the Firebase console!")
                    print("Go to Firebase Console > Authentication > Sign-in method and enable Anonymous authentication")
                }
                
                completion(false, error)
                return
            }
            
            guard let user = authResult?.user else {
                print("Warning: Auth successful but no user returned")
                completion(false, NSError(domain: "FirebaseService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to get user after authentication"]))
                return
            }
            
            self.userId = user.uid
            self.isAuthenticated = true
            print("User signed in anonymously with ID: \(user.uid)")
            completion(true, nil)
        }
    }
    
    // Get current Firebase user ID
    func getCurrentUserId() -> String? {
        return Auth.auth().currentUser?.uid
    }
    
    // MARK: - Firestore Integration
    
    // Save a trip to Firestore
    func saveTrip(_ trip: Trip, completion: @escaping (Bool, Error?) -> Void) {
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        // Make sure user is authenticated before saving
        guard Auth.auth().currentUser != nil else {
            // If not authenticated, try to authenticate first
            signInAnonymously { success, error in
                if success {
                    // Retry saving after authentication
                    self.saveTrip(trip, completion: completion)
                } else {
                    completion(false, error ?? NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"]))
                }
            }
            return
        }
        
        do {
            try db.collection("trips").document(trip.id).setData(from: trip) { error in
                if let error = error {
                    print("Error saving trip: \(error.localizedDescription)")
                    completion(false, error)
                } else {
                    print("Trip successfully saved!")
                    completion(true, nil)
                }
            }
        } catch {
            print("Error encoding trip: \(error.localizedDescription)")
            completion(false, error)
        }
    }
    
    // Fetch a trip from Firestore by invite code
    func fetchTrip(withInviteCode code: String, completion: @escaping (Trip?, Error?) -> Void) {
        // Make sure user is authenticated before fetching
        guard Auth.auth().currentUser != nil else {
            // If not authenticated, try to authenticate first
            signInAnonymously { success, error in
                if success {
                    // Retry fetching after authentication
                    self.fetchTrip(withInviteCode: code, completion: completion)
                } else {
                    completion(nil, error ?? NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"]))
                }
            }
            return
        }
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        db.collection("trips")
            .whereField("inviteCode", isEqualTo: code)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error fetching trip: \(error.localizedDescription)")
                    completion(nil, error)
                    return
                }
                
                guard let document = snapshot?.documents.first else {
                    completion(nil, NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip not found"]))
                    return
                }
                
                do {
                    let trip = try document.data(as: Trip.self)
                    completion(trip, nil)
                } catch {
                    print("Error decoding trip: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
    }
    
    // Listen for real-time updates to a trip
    func listenForTripUpdates(tripId: String, completion: @escaping (Trip?, Error?) -> Void) -> Any? {
        // Make sure user is authenticated before listening
        guard Auth.auth().currentUser != nil else {
            print("Error: User not authenticated for listening to trip updates")
            completion(nil, NSError(domain: "FirebaseService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Authentication required"]))
            return nil
        }
        
        // Real Firestore implementation
        let db = Firestore.firestore()
        
        let listener = db.collection("trips").document(tripId)
            .addSnapshotListener { documentSnapshot, error in
                guard let document = documentSnapshot else {
                    print("Error fetching document: \(error?.localizedDescription ?? "Unknown error")")
                    completion(nil, error)
                    return
                }
                
                guard document.exists else {
                    completion(nil, NSError(domain: "FirebaseService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Trip no longer exists"]))
                    return
                }
                
                do {
                    let trip = try document.data(as: Trip.self)
                    completion(trip, nil)
                } catch {
                    print("Error decoding trip: \(error.localizedDescription)")
                    completion(nil, error)
                }
            }
            
        return listener
    }
    
    // Stop listening for updates
    func stopListening(listener: Any) {
        if let listener = listener as? ListenerRegistration {
            listener.remove()
        }
    }
    
    // Generate a shareable link/message for the invite code
    func generateShareMessage(inviteCode: String, tripName: String) -> String {
        return """
        Join my trip "\(tripName)" in Travel Split!
        
        Use invite code: \(inviteCode)
        
        Download the app and enter this code to join.
        """
    }
    
    // Generate a unique ID for an unclaimed participant
    // This helps tie the unclaimed participant to the authenticated user who created it
    func generateUnclaimedParticipantId(name: String) -> String {
        // Format: "unclaimed_{auth_user_id}_{random_uuid}_{sanitized_name}"
        let authUserId = Auth.auth().currentUser?.uid ?? "no_auth"
        let randomPart = UUID().uuidString.prefix(8)
        // Sanitize name to remove spaces and special characters, lowercase
        let sanitizedName = name
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        
        return "unclaimed_\(authUserId)_\(randomPart)_\(sanitizedName)"
    }
    
    // MARK: - Trip Operations
    
    /// Delete a trip from Firestore
    func deleteTrip(withId id: String, completion: @escaping (Error?) -> Void) {
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