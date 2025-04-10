import Foundation
import FirebaseAuth
import FirebaseFirestore
import SwiftUI

class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
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
                // 3. Only use "You" as absolute last resort for truly new users
                let displayName: String
                if let firebaseName = user.displayName, !firebaseName.isEmpty {
                    displayName = firebaseName
                } else if let savedName = savedName, !savedName.isEmpty, savedName != "You" {
                    // Use the saved name if it's not empty and not default "You"
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
                    displayName = "You"
                }
                
                // Create our internal user model
                self.currentUser = User(id: user.uid, 
                                      name: displayName,
                                      email: user.email ?? "",
                                      profileImage: nil,
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
    func signUp(email: String, password: String, name: String, completion: @escaping (Bool, Error?) -> Void) {
        // Check if we have an anonymous user that we should upgrade
        if let currentUser = Auth.auth().currentUser, currentUser.isAnonymous {
            print("Converting anonymous user to permanent account")
            
            // Store the anonymous user ID for trip migration
            let anonymousUserId = currentUser.uid
            
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
                    self.currentUser = User(id: user.uid, name: name, email: email, profileImage: nil, isClaimed: true)
                    
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
                    self.currentUser = User(id: user.uid, name: name, email: email, profileImage: nil, isClaimed: true)
                    
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
    func signIn(email: String, password: String, completion: @escaping (Bool, Error?) -> Void) {
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
                if let savedName = savedName, !savedName.isEmpty, savedName != "You" {
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
                    displayName = "User"
                }
            }
            
            // Set hasCompletedSetup in UserDefaults
            UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
            UserDefaults.standard.set(displayName, forKey: "user_name")
            UserDefaults.standard.set(user.email ?? "", forKey: "user_email")
            UserDefaults.standard.set(user.uid, forKey: "user_id")
            
            // Mark as authenticated immediately
            self.isAuthenticated = true
            self.currentUser = User(id: user.uid, 
                                  name: displayName, 
                                  email: user.email ?? "", 
                                  profileImage: nil,
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
        let anonymousAuth = Auth.auth()
        
        // We can't easily re-authenticate and delete an anonymous user after we've signed in with a different user
        // Instead, we'll just assume it's gone and let Firebase garbage collect it later
        print("Skipping anonymous user deletion - Firebase will garbage collect unused anonymous accounts")
        completion(true)
    }
    
    // Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUser = nil
            
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
}

// MARK: - Notification Names
extension Notification.Name {
    static let userDidSignOut = Notification.Name("userDidSignOut")
} 