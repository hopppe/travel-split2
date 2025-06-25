import SwiftUI
import FirebaseAuth

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    @ObservedObject var tripViewModel: TripViewModel
    
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSignOutConfirmation = false
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var isInitialSetup: Bool
    @State private var isAnonymousUser = true
    @State private var authListener: AuthStateDidChangeListenerHandle?
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    
    init(tripViewModel: TripViewModel, isInitialSetup: Bool = false) {
        self.tripViewModel = tripViewModel
        self.isInitialSetup = isInitialSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Profile")) {
                    TextField("Name", text: $userName)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    
                    if !isAnonymousUser {
                        TextField("Email", text: $userEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(true)
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                    } else {
                        Button(action: saveProfile) {
                            Text(isAnonymousUser ? "Save Name" : "Update Profile")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(userName.isEmpty || isLoading)
                    }
                }
                
                if isAnonymousUser {
                    Section(header: Text("Account")) {
                        Button("Sign In") {
                            showSignIn = true
                        }
                        
                        Button("Create Account") {
                            showSignUp = true
                        }
                        
                        Button("Delete All Data", role: .destructive) {
                            showDeleteAccountConfirmation = true
                        }
                        .disabled(isDeletingAccount)
                    }
                } else {
                    Section(header: Text("Account Settings")) {
                        Button("Sign Out", role: .destructive) {
                            showSignOutConfirmation = true
                        }
                        
                        Button("Delete Account", role: .destructive) {
                            showDeleteAccountConfirmation = true
                        }
                        .disabled(isDeletingAccount)
                    }
                }
                
                // Feedback section
                Section(header: Text("Feedback")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Please submit any feedback for the app:")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Button("ethan@ingenuitylabs.net") {
                            // Create mailto URL
                            if let url = URL(string: "mailto:ethan@ingenuitylabs.net?subject=EquiSplit App Feedback") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isInitialSetup ? "Welcome to EquiSplit" : "Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !isInitialSetup {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showSignIn) {
                SignInView(hasCompletedSetup: .constant(true))
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(hasCompletedSetup: .constant(true))
            }
            .onAppear {
                refreshUserState()
                // Add auth state listener when view appears
                authListener = Auth.auth().addStateDidChangeListener { (auth, user) in
                    DispatchQueue.main.async {
                        self.refreshUserState()
                    }
                }
                
                // Add notification observer for authentication changes
                NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("AuthenticationDidChange"),
                    object: nil,
                    queue: .main
                ) { _ in
                    self.refreshUserState()
                }
            }
            .onDisappear {
                // Remove auth state listener when view disappears
                if let authListener = authListener {
                    Auth.auth().removeStateDidChangeListener(authListener)
                }
                
                // Remove notification observer
                NotificationCenter.default.removeObserver(
                    self,
                    name: NSNotification.Name("AuthenticationDidChange"),
                    object: nil
                )
            }
            .onChange(of: showSignIn) { isPresented in
                if !isPresented {
                    // Refresh when Sign In sheet is dismissed
                    refreshUserState()
                }
            }
            .onChange(of: showSignUp) { isPresented in
                if !isPresented {
                    // Refresh when Sign Up sheet is dismissed 
                    refreshUserState()
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Sign Out Confirmation", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert(isAnonymousUser ? "Delete All Data" : "Delete Account", isPresented: $showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button(isAnonymousUser ? "Delete All Data" : "Delete Account", role: .destructive) {
                    performDeleteAccount()
                }
            } message: {
                if isAnonymousUser {
                    Text("Are you sure you want to delete all your data? This action cannot be undone.\n\nAll your trips, expenses, and personal information will be permanently deleted from this device. You will be taken back to the welcome screen.")
                } else {
                    Text("Are you sure you want to delete your account? This action cannot be undone.\n\nYour account will be permanently deleted, but you will remain as a placeholder participant in any groups you've joined. Other group members will still be able to see your expenses and balances.")
                }
            }
            .interactiveDismissDisabled(isInitialSetup)
        }
    }
    
    private func refreshUserState() {
        if let firebaseUser = Auth.auth().currentUser {
            isAnonymousUser = firebaseUser.isAnonymous
            
            // First determine if we're dealing with a logged-in user with email
            if let email = firebaseUser.email, !email.isEmpty {
                userEmail = email
                
                // For the name, use priority order:
                // 1. Firebase display name
                // 2. Current name in the UI (if not default)
                // 3. Current user model name
                // 4. Default to existing value
                if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                    userName = displayName
                } else if userName.isEmpty || userName == "You" {
                    // Only update if current name is empty or default
                    if tripViewModel.currentUser.name != "You" {
                        userName = tripViewModel.currentUser.name
                    }
                }
                // Otherwise keep existing name in the field
            } else {
                // Anonymous user
                isAnonymousUser = true
                
                // For anonymous users, preserve their custom name if they set one
                if userName.isEmpty || userName == "You" {
                    // If current profile name is empty or default "You",
                    // check if the model has a custom name
                    if tripViewModel.currentUser.name != "You" {
                        userName = tripViewModel.currentUser.name
                    } else {
                        // Try to get name from Firebase
                        if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                            userName = displayName
                        } else {
                            // Last resort - keep current value or use model default
                            if userName.isEmpty {
                                userName = tripViewModel.currentUser.name
                            }
                        }
                    }
                }
                // Otherwise keep existing name in the field
                
                userEmail = ""
            }
        } else {
            // No Firebase user at all - keep using existing data
            isAnonymousUser = true
            
            // Only update if current UI value is empty
            if userName.isEmpty {
                userName = tripViewModel.currentUser.name
            }
            
            if userEmail.isEmpty {
                userEmail = tripViewModel.currentUser.email
            }
        }
        
        print("Profile refreshed: name=\(userName), email=\(userEmail), anonymous=\(isAnonymousUser)")
    }
    
    private func performSignOut() {
        // Allow anonymous auth for future sessions if needed
        UserDefaults.standard.set(true, forKey: "allowAnonymousAuth")
        
        // Set hasCompletedSetup to false to show welcome screen
        UserDefaults.standard.set(false, forKey: "hasCompletedSetup")
        
        // Perform the actual sign out
        authService.signOut()
    }
    
    private func performDeleteAccount() {
        isDeletingAccount = true
        
        if isAnonymousUser {
            // For anonymous users, just clear all local data and reset app state
            performAnonymousDataDeletion()
        } else {
            // For signed-in users, use the full account deletion process
            authService.deleteAccount { success, error in
                DispatchQueue.main.async {
                    self.isDeletingAccount = false
                    
                    if success {
                        // Account deletion successful - the AuthenticationService will handle
                        // clearing local data and posting notifications
                        print("Account deletion completed successfully")
                        
                        // Reset the trip view model to clear any cached data
                        self.tripViewModel.reset()
                        
                        // Dismiss the profile view
                        self.dismiss()
                    } else {
                        // Show error message
                        self.errorMessage = error?.localizedDescription ?? "Failed to delete account"
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func performAnonymousDataDeletion() {
        print("Deleting all anonymous user data")
        
        // Stop all Firebase listeners first
        NotificationCenter.default.post(name: .stopAllListeners, object: nil)
        
        // Clear all UserDefaults data
        UserDefaults.standard.removeObject(forKey: "user_id")
        UserDefaults.standard.removeObject(forKey: "user_name")
        UserDefaults.standard.removeObject(forKey: "user_email")
        UserDefaults.standard.removeObject(forKey: "hasCompletedSetup")
        UserDefaults.standard.set(true, forKey: "allowAnonymousAuth")
        
        // Sign out from Firebase (this will delete the anonymous account)
        authService.signOut()
        
        // Reset the trip view model to clear all cached data
        tripViewModel.reset()
        
        // Post notification to trigger app state reset
        NotificationCenter.default.post(name: .userAccountDeleted, object: nil)
        
        DispatchQueue.main.async {
            self.isDeletingAccount = false
            
            // Dismiss the profile view
            self.dismiss()
        }
    }
    
    private func saveProfile() {
        guard !userName.isEmpty else { return }
        
        isLoading = true
        
        if !isAnonymousUser, let currentUser = Auth.auth().currentUser {
            let changeRequest = currentUser.createProfileChangeRequest()
            changeRequest.displayName = userName
            changeRequest.commitChanges { [self] error in
                if let error = error {
                    print("Error updating Firebase profile: \(error.localizedDescription)")
                    self.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                    self.showError = true
                    self.isLoading = false
                    return
                }
                
                self.updateLocalUserProfile()
            }
        } else {
            updateLocalUserProfile()
        }
    }
    
    private func updateLocalUserProfile() {
        var updatedUser = tripViewModel.currentUser
        updatedUser.name = userName
        updatedUser.email = userEmail
        
        tripViewModel.updateCurrentUser(updatedUser)
        
        tripViewModel.userManager.updateUser(updatedUser)
        
        UserDefaults.standard.set(userName, forKey: "user_name")
        UserDefaults.standard.set(userEmail, forKey: "user_email")
        UserDefaults.standard.set(updatedUser.id, forKey: "user_id")
        
        isLoading = false
        dismiss()
    }
}

#Preview {
    UserProfileView(tripViewModel: TripViewModel(currentUser: User.create(name: "You", email: "you@example.com")))
} 