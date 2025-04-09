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
            
            if let email = firebaseUser.email, !email.isEmpty {
                userEmail = email
                
                if let displayName = firebaseUser.displayName, !displayName.isEmpty {
                    userName = displayName
                } else {
                    userName = tripViewModel.currentUser.name
                }
            } else {
                isAnonymousUser = true
                userName = tripViewModel.currentUser.name
                userEmail = ""
            }
        } else {
            isAnonymousUser = true
            userName = tripViewModel.currentUser.name
            userEmail = tripViewModel.currentUser.email
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