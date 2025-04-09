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
                
                // Get the display name, with empty check
                let displayName = user.displayName?.isEmpty ?? true ? "You" : user.displayName!
                
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
            
            // Get the display name, with empty check
            let displayName = user.displayName?.isEmpty ?? true ? "User" : user.displayName!
            
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
            
            completion(true, nil)
        }
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