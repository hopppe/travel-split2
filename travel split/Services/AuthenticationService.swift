import Foundation
import FirebaseAuth
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
                self.currentUser = User(id: user.uid, 
                                      name: user.displayName ?? "User",
                                      email: user.email ?? "",
                                      profileImage: nil,
                                      isClaimed: true)
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
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
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
            changeRequest.commitChanges { error in
                if let error = error {
                    print("Error updating profile: \(error.localizedDescription)")
                }
                completion(true, nil)
            }
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
            
            completion(true, nil)
        }
    }
    
    // Sign out
    func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
            currentUser = nil
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