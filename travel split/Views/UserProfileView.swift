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
                    }
                } else {
                    Section(header: Text("Account Settings")) {
                        Button("Sign Out", role: .destructive) {
                            showSignOutConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(isInitialSetup ? "Welcome to Free Split" : "Edit Profile")
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