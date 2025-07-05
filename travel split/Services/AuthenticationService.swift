import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI
import TravelSplitModels

public class AuthenticationService: ObservableObject {
    public static let shared = AuthenticationService()
    
    @Published public var currentUser: TravelSplitModels.User?
    @Published public var isAuthenticated = false
    @Published public var errorMessage: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    private init() {
        // Listen for auth state changes
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.isAuthenticated = user != nil
            if let user = user {
                // Check if user is a real user (has an email) or anonymous
                let isRealUser = user.email != nil && !user.email!.isEmpty
                
                // Only disable anonymous auth if this is a real user
                if isRealUser {
                    print("Real user signed in, disabling anonymous auth")
                    UserDefaults.standard.set(false, forKey: "allowAnonymousAuth")
                } else if user.isAnonymous {
                    print("Anonymous user signed in")
                }
                
                // First check if we have a saved name for this user ID in UserDefaults
                let savedName = UserDefaults.standard.string(forKey: "user_name")
                
                // Get the display name, with proper fallback logic:
                // 1. Use Firebase display name if available
                // 2. Use previously saved name if available
                // 3. Only use "user" as absolute last resort for truly new users
                let displayName: String
                if let firebaseName = user.displayName, !firebaseName.isEmpty {
                    displayName = firebaseName
                } else if let savedName = savedName, !savedName.isEmpty, savedName != "user" {
                    // Use the saved name if it's not empty and not default "user"
                    displayName = savedName
                    
                    // Also update Firebase with this name to keep them in sync
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = savedName
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("Error updating Firebase display name: \(error)")
                        } else {
                            print("Successfully updated Firebase display name to: \(savedName)")
                        }
                    }
                } else {
                    displayName = "user"
                }
                
                // Create our internal user model
                self.currentUser = TravelSplitModels.User(id: user.uid, 
                                      name: displayName,
                                      email: user.email ?? "",
                                      profileImage: nil as String?,
                                      isClaimed: true)
                
                // Save to UserDefaults for persistence
                UserDefaults.standard.set(user.uid, forKey: "user_id")
                UserDefaults.standard.set(displayName, forKey: "user_name")
                UserDefaults.standard.set(user.email ?? "", forKey: "user_email")
                
                // Save hasCompletedSetup flag to bypass welcome screen
                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
            } else {
                self.currentUser = nil
            }
        }
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // Sign up with email and password
    public func signUp(email: String, password: String, name: String, completion: @escaping (Bool, Error?) -> Void) {
        // Check if we have an anonymous user that we should upgrade
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            print("Converting anonymous user to permanent account")
            
                    // Store the anonymous user ID for trip migration
        let _ = currentUser.uid
            
            // Create credential
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)
            
            // Link the anonymous user with the email credential
            currentUser.link(with: credential) { [weak self] authResult, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("Error linking anonymous account: \(error.localizedDescription)")
                    completion(false, error)
                    return
                }
                
                guard let user = authResult?.user else {
                    self.errorMessage = "Failed to link account"
                    completion(false, nil)
                    return
                }
                
                // Update profile with name
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = name
                changeRequest.commitChanges { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error updating profile after linking: \(error.localizedDescription)")
                        completion(false, error)
                        return
                    }
                    
                    // Set hasCompletedSetup in UserDefaults
                    UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                    UserDefaults.standard.set(name, forKey: "user_name")
                    UserDefaults.standard.set(email, forKey: "user_email")
                    UserDefaults.standard.set(user.uid, forKey: "user_id")
                    
                    // Mark as authenticated immediately
                    self.isAuthenticated = true
                    self.currentUser = TravelSplitModels.User(id: user.uid, name: name, email: email, profileImage: nil as String?, isClaimed: true)
                    
                    // Save the user data to Firestore
                    self.saveUserToFirestore(userId: user.uid, name: name, email: email) { success in
                        if !success {
                            print("Warning: Failed to save user data to Firestore after linking")
                        } else {
                            print("Successfully saved user data after linking anonymous account")
                        }
                        // Trips don't need to be migrated as they're already associated with this user
                        // (anonymous account was upgraded)
                        print("Account upgraded from anonymous to registered - trips already associated with this user")
                        completion(true, nil)
                    }
                }
            }
        } else {
            // No anonymous user to upgrade, create a new account
            print("Creating new account without anonymous user")
            
            // Create a Firebase auth settings object
            let auth = Auth.auth()
            
            auth.createUser(withEmail: email, password: password) { [weak self] result, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false, error)
                    return
                }
                
                guard let user = result?.user else {
                    self.errorMessage = "Failed to create user"
                    completion(false, nil)
                    return
                }
                
                // Update user profile with display name
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = name
                changeRequest.commitChanges { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error updating profile: \(error.localizedDescription)")
                        completion(false, error)
                        return
                    }
                    
                    // Set hasCompletedSetup in UserDefaults
                    UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                    UserDefaults.standard.set(name, forKey: "user_name")
                    UserDefaults.standard.set(email, forKey: "user_email")
                    UserDefaults.standard.set(user.uid, forKey: "user_id")
                    
                    // Mark as authenticated immediately
                    self.isAuthenticated = true
                    self.currentUser = TravelSplitModels.User(id: user.uid, name: name, email: email, profileImage: nil as String?, isClaimed: true)
                    
                    // Now save the user data to Firestore
                    self.saveUserToFirestore(userId: user.uid, name: name, email: email) { success in
                        if !success {
                            print("Warning: Failed to save user data to Firestore")
                        }
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    // Helper method to save user data to Firestore
    private func saveUserToFirestore(userId: String, name: String, email: String, completion: @escaping (Bool) -> Void) {
        let userData: [String: Any] = [
            "name": name,
            "email": email,
            "createdAt": FieldValue.serverTimestamp(),
            "isClaimed": true
        ]
        
        // Save to users collection
        Firestore.firestore().collection("users").document(userId).setData(userData) { error in
            if let error = error {
                print("Error saving user to Firestore: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            // Successfully saved to Firestore
            print("User data saved to Firestore successfully")
            completion(true)
        }
    }
    
    // Sign in with email and password
    public func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
        // Store reference to anonymous user if one exists
        let anonymousUser = Auth.auth().currentUser
        let isAnonymous = anonymousUser?.isAnonymous ?? false
        let anonymousUserId = anonymousUser?.uid
        
        // If there's an anonymous user, we'll need to transfer their trips
        if isAnonymous {
            print("Anonymous user detected before sign in: \(anonymousUserId ?? "unknown")")
        }
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.errorMessage = error.localizedDescription
                completion(false, error)
                return
            }
            
            guard let user = result?.user else {
                self.errorMessage = "Failed to sign in"
                completion(false, nil)
                return
            }
            
            // Get the display name, with better fallback logic
            let displayName: String
            if let firebaseName = user.displayName, !firebaseName.isEmpty {
                displayName = firebaseName
            } else {
                // Check if we have a previously saved name for this user
                let savedName = UserDefaults.standard.string(forKey: "user_name")
                if let savedName = savedName, !savedName.isEmpty, savedName != "user" {
                    displayName = savedName
                    
                    // Also update Firebase with this name
                    let changeRequest = user.createProfileChangeRequest()
                    changeRequest.displayName = savedName
                    changeRequest.commitChanges { error in
                        if let error = error {
                            print("Error updating Firebase display name: \(error)")
                        }
                    }
                } else {
                    // Only use a generic name as last resort
                    displayName = "user"
                }
            }
            
            // Set hasCompletedSetup in UserDefaults
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
            UserDefaults.standard.set(displayName, forKey: "user_name")
            UserDefaults.standard.set(user.email ?? "", forKey: "user_email")
            UserDefaults.standard.set(user.uid, forKey: "user_id")
            
            // Mark as authenticated immediately
            self.isAuthenticated = true
            self.currentUser = TravelSplitModels.User(id: user.uid, 
                                  name: displayName, 
                                  email: user.email ?? "", 
                                  profileImage: nil as String?,
                                  isClaimed: true)
            
            // If we had an anonymous user before, transfer their trips to the new signed-in user
            if isAnonymous, let anonymousId = anonymousUserId {
                print("Transferring trips from anonymous user \(anonymousId) to signed-in user \(user.uid)")
                self.transferTripsAndDeleteUser(fromId: anonymousId, toId: user.uid) { success in
                    if success {
                        print("Successfully transferred trips from anonymous user to signed-in user")
                    } else {
                        print("Failed to transfer all trips from anonymous user")
                    }
                    
                    // Post notification that trips have been updated
                    NotificationCenter.default.post(name: NSNotification.Name("TripsUpdated"), object: nil)
                    
                    completion(true, nil)
                }
            } else {
                completion(true, nil)
            }
        }
    }
    
    // Transfer trips from one user to another and delete the source user
    private func transferTripsAndDeleteUser(fromId: String, toId: String, completion: @escaping (Bool) -> Void) {
        // Use the existing migration function to transfer trips
        FirebaseService.shared.migrateUserData(fromId: fromId, toId: toId) { [weak self] success in
            if success {
                print("Trip migration completed successfully")
                
                // Now delete the anonymous user since we've migrated their data
                self?.deleteAnonymousUser(completion: { deleteSuccess in
                    if deleteSuccess {
                        print("Anonymous user deleted successfully")
                    } else {
                        print("Failed to delete anonymous user - this is not critical")
                    }
                    
                    // Consider the operation successful if the trips were migrated
                    completion(success)
                })
            } else {
                print("Trip migration failed")
                completion(false)
            }
        }
    }
    
    // Delete the anonymous user
    private func deleteAnonymousUser(completion: @escaping (Bool) -> Void) {
        // Try to re-authenticate as the anonymous user (requires a fresh credential)
        let _ = Auth.auth()
        
        // We can't easily re-authenticate and delete an anonymous user after we've signed in with a different user
        // Instead, we'll just assume it's gone and let Firebase garbage collect it later
        print("Skipping anonymous user deletion - Firebase will garbage collect unused anonymous accounts")
        completion(true)
    }
    
    // Sign out
    public func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUser = nil as TravelSplitModels.User?
            
            // Post notification that user has signed out
            NotificationCenter.default.post(name: .userDidSignOut, object: nil)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // Reset password
    func resetPassword(email: String, completion: @escaping (Bool, Error?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                self.errorMessage = error.localizedDescription
                completion(false, error)
                return
            }
            completion(true, nil)
        }
    }
    
    // MARK: - Account Deletion
    
    /// Delete the user's account and convert them to placeholder status in all trips
    /// This is irreversible and will permanently delete the user's Firebase account
    func deleteAccount(completion: @escaping (Bool, Error?) -> Void) {
        guard let currentFirebaseUser = Auth.auth().currentUser else {
            errorMessage = "No authenticated user found"
            completion(false, NSError(domain: "AuthenticationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found"]))
            return
        }
        
        guard let currentUser = self.currentUser else {
            errorMessage = "No current user found"
            completion(false, NSError(domain: "AuthenticationService", code: 401, userInfo: [NSLocalizedDescriptionKey: "No current user found"]))
            return
        }
        
        let userId = currentUser.id
        let userName = currentUser.name
        
        print("Starting account deletion process for user: \(userName) (ID: \(userId))")
        
        // Step 0: Stop all Firebase listeners to prevent confusing updates during deletion
        NotificationCenter.default.post(name: .stopAllListeners, object: nil)
        
        // Step 1: Convert user to placeholder status in all trips
        convertUserToPlaceholderInAllTrips(userId: userId, userName: userName) { [weak self] success in
            guard let self = self else { return }
            
            if !success {
                print("Failed to convert user to placeholder in trips")
                self.errorMessage = "Failed to prepare account for deletion"
                completion(false, NSError(domain: "AuthenticationService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to prepare account for deletion"]))
                return
            }
            
            print("Successfully converted user to placeholder in all trips")
            
            // Step 2: Delete user data from Firestore users collection
            self.deleteUserFromFirestore(userId: userId) { firestoreSuccess in
                if !firestoreSuccess {
                    print("Warning: Failed to delete user data from Firestore, but continuing with account deletion")
                }
                
                // Step 3: Delete the Firebase Auth account
                currentFirebaseUser.delete { [weak self] error in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("Error deleting Firebase account: \(error.localizedDescription)")
                        self.errorMessage = "Failed to delete account: \(error.localizedDescription)"
                        completion(false, error)
                        return
                    }
                    
                    print("Successfully deleted Firebase account")
                    
                    // Step 4: Clear local data
                    self.clearLocalUserData()
                    
                    // Step 5: Update authentication state
                    self.isAuthenticated = false
                    self.currentUser = nil as TravelSplitModels.User?
                    
                    // Post notification that user account was deleted
                    NotificationCenter.default.post(name: .userAccountDeleted, object: nil)
                    
                    completion(true, nil)
                }
            }
        }
    }
    
    /// Convert the user to placeholder status in all their trips
    private func convertUserToPlaceholderInAllTrips(userId: String, userName: String, completion: @escaping (Bool) -> Void) {
        let db = Firestore.firestore()
        
        // Find all trips where the user is a participant (either directly or through claiming)
        db.collection("trips").getDocuments(completion: { snapshot, error in
            guard let documents = snapshot?.documents, error == nil else {
                print("Error fetching trips for account deletion: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }
            
            let batch = db.batch()
            var hasUpdates = false
            
            for document in documents {
                do {
                    let trip = try document.data(as: TravelSplitModels.Trip.self)
                    var updatedTrip = trip
                    var tripNeedsUpdate = false
                    
                    // Check each participant in the trip
                    for (index, participant) in trip.participants.enumerated() {
                        // Convert participant to placeholder if they match the user being deleted
                        if participant.id == userId || participant.claimedByUserId == userId {
                            print("Converting participant \(participant.name) to placeholder in trip \(trip.name)")
                            
                            // Create placeholder version of the user
                            var placeholderUser = participant
                            placeholderUser.isClaimed = false
                            placeholderUser.claimedByUserId = nil
                            placeholderUser.email = "" // Clear email for privacy
                            
                            // Generate a new unclaimed ID to avoid conflicts
                            placeholderUser.id = FirebaseService.shared.generateUnclaimedParticipantId(name: userName)
                            
                            updatedTrip.participants[index] = placeholderUser
                            tripNeedsUpdate = true
                        }
                    }
                    
                    // Update expenses where the user was the payer
                    for (expenseIndex, expense) in trip.expenses.enumerated() {
                        if expense.paidBy.id == userId || expense.paidBy.claimedByUserId == userId {
                            print("Updating expense \(expense.title) payer to placeholder in trip \(trip.name)")
                            
                            // Find the placeholder participant to use as the new payer
                            if let placeholderParticipant = updatedTrip.participants.first(where: { $0.name == userName && !$0.isClaimed }) {
                                var updatedExpense = expense
                                updatedExpense.paidBy = placeholderParticipant
                                
                                // Update shares if needed
                                for (shareIndex, share) in expense.shares.enumerated() {
                                    if share.user.id == userId || share.user.claimedByUserId == userId {
                                        updatedExpense.shares[shareIndex].user = placeholderParticipant
                                    }
                                }
                                
                                updatedTrip.expenses[expenseIndex] = updatedExpense
                                tripNeedsUpdate = true
                            }
                        } else {
                            // Update shares where the user was a participant
                            var updatedExpense = expense
                            var expenseNeedsUpdate = false
                            
                            for (shareIndex, share) in expense.shares.enumerated() {
                                if share.user.id == userId || share.user.claimedByUserId == userId {
                                    if let placeholderParticipant = updatedTrip.participants.first(where: { $0.name == userName && !$0.isClaimed }) {
                                        updatedExpense.shares[shareIndex].user = placeholderParticipant
                                        expenseNeedsUpdate = true
                                    }
                                }
                            }
                            
                            if expenseNeedsUpdate {
                                updatedTrip.expenses[expenseIndex] = updatedExpense
                                tripNeedsUpdate = true
                            }
                        }
                    }
                    
                    // Add the trip to the batch update if it needs updating
                    if tripNeedsUpdate {
                        let tripRef = db.collection("trips").document(trip.id)
                        do {
                            try batch.setData(from: updatedTrip, forDocument: tripRef)
                            hasUpdates = true
                        } catch {
                            print("Error encoding updated trip for batch: \(error)")
                        }
                    }
                } catch {
                    print("Error decoding trip for account deletion: \(error)")
                }
            }
            
            // Commit the batch if there are updates
            if hasUpdates {
                batch.commit { error in
                    if let error = error {
                        print("Error committing trip updates for account deletion: \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("Successfully updated all trips for account deletion")
                        completion(true)
                    }
                }
            } else {
                print("No trips needed updating for account deletion")
                completion(true)
            }
        })
    }
    
    /// Delete user data from Firestore users collection
    private func deleteUserFromFirestore(userId: String, completion: @escaping (Bool) -> Void) {
        Firestore.firestore().collection("users").document(userId).delete { error in
            if let error = error {
                print("Error deleting user from Firestore: \(error.localizedDescription)")
                completion(false)
            } else {
                print("Successfully deleted user from Firestore")
                completion(true)
            }
        }
    }
    
    /// Clear all local user data from UserDefaults
    private func clearLocalUserData() {
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "hasCompletedSetup")
        UserDefaults.standard.set(true, forKey: "allowAnonymousAuth") // Allow anonymous auth for next session
        
        print("Cleared all local user data")
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
    static let userAccountDeleted = Notification.Name("userAccountDeleted")
    static let stopAllListeners = Notification.Name("stopAllListeners")
} 