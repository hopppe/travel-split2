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
    
    // App bundle identifiers for deep linking
    private let iosBundleId = "com.ethanhoppe.travel-split"
    private let androidPackageName = "com.ethanhoppe.travelsplit" // Update this if you have an Android version
    
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
        
        // First check if we already have an anonymous user
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            print("Already have an anonymous user: \(currentUser.uid)")
            self.userId = currentUser.uid
            self.isAuthenticated = true
            
            // Load user data from UserDefaults if available
            if let name = UserDefaults.standard.string(forKey: "user_name"),
               let _ = UserDefaults.standard.string(forKey: "user_email"),
               let savedUserId = UserDefaults.standard.string(forKey: "user_id"),
               !name.isEmpty {
                print("Found saved user data for anonymous user: \(name)")
                
                // If the saved ID doesn't match the current Firebase ID, update it
                if savedUserId != currentUser.uid {
                    print("Updating saved user ID to match Firebase ID")
                    UserDefaults.standard.set(currentUser.uid, forKey: "user_id")
                }
            }
            
            completion(true, nil)
            return
        }
        
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
            
            // Check if we have existing user data from a previous session
            if let name = UserDefaults.standard.string(forKey: "user_name"),
               let _ = UserDefaults.standard.string(forKey: "user_email"),
               let savedUserId = UserDefaults.standard.string(forKey: "user_id"),
               !name.isEmpty {
                print("Found saved user data: \(name)")
                
                // If the saved ID doesn't match the current Firebase ID, update it
                if savedUserId != user.uid {
                    print("Updating saved user ID to match Firebase ID")
                    UserDefaults.standard.set(user.uid, forKey: "user_id")
                }
            } else {
                // No saved data, create default
                UserDefaults.standard.set("You", forKey: "user_name")
                UserDefaults.standard.set("", forKey: "user_email")
                UserDefaults.standard.set(user.uid, forKey: "user_id")
            }
            
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
            .limit(to: 1)
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
    
    // MARK: - Deep Linking
    
    /// Create a deep link using direct URL scheme for development testing
    func createDeepLink(inviteCode: String) -> URL {
        // Create a direct URL scheme link for testing
        let directURL = "travelsplit://join?code=\(inviteCode)"
        print("Development direct URL for testing: \(directURL)")
        return URL(string: directURL)!
        
        /* DYNALINKS IMPLEMENTATION (UNCOMMENT WHEN APP IS PUBLISHED)
        
        // Create a deep link URL that contains the invite code
        let deepLink = "https://travelsplit.app/join?code=\(inviteCode)"
        
        // Create the Dynalinks URL - this format works without registering
        // Format: https://{subdomain}.dynalinks.com/?link={deep_link}&ibi={ios_bundle_id}&apn={android_package_name}
        let encodedDeepLink = deepLink.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? deepLink
        let dynalinkURL = "https://travelsplit.dynalinks.com/?link=\(encodedDeepLink)&ibi=\(iosBundleId)&apn=\(androidPackageName)"
        
        print("Generated Dynalink: \(dynalinkURL)")
        return URL(string: dynalinkURL)!
        */
    }
    
    // Generate a shareable message for the invite code
    func generateShareMessage(inviteCode: String, tripName: String) -> String {
        // Create a deep link
        let deepLinkURL = createDeepLink(inviteCode: inviteCode)
        
        return """
        Join my trip "\(tripName)" in Travel Split!
        
        Link: \(deepLinkURL)
        Code: \(inviteCode)
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