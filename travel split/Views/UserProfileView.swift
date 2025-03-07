import SwiftUI

struct UserProfileView: View {
    @ObservedObject var tripViewModel: TripViewModel
    @State private var userName: String = ""
    @State private var userEmail: String = ""
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var authErrorShown = false
    
    // Detect if this is initial setup
    var isInitialSetup: Bool {
        return tripViewModel.currentUser.name == "You" && 
               tripViewModel.currentUser.email == "you@example.com"
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Your Profile")) {
                    TextField("Your Name", text: $userName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                    
                    TextField("Email (Optional)", text: $userEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
                
                Section {
                    Button(action: saveProfile) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text(isInitialSetup ? "Get Started" : "Save Profile")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(userName.isEmpty || isLoading)
                    .buttonStyle(.borderedProminent)
                }
                
                if authErrorShown {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("⚠️ Authentication Error")
                                .font(.headline)
                                .foregroundColor(.red)
                            Text("Please ensure Anonymous Authentication is enabled in your Firebase Console.")
                            
                            // Add a workaround for testing without authentication
                            Button("Continue Without Authentication (Development Only)") {
                                // Still save the profile locally even without auth
                                saveProfileLocally()
                            }
                            .padding(.top, 8)
                            .font(.caption)
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                if isInitialSetup {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome to Travel Split!")
                                .font(.headline)
                            Text("Your name helps others identify you when splitting expenses.")
                            Text("Your email is optional and only used to help friends find you.")
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(isInitialSetup ? "Welcome" : "Edit Profile")
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
            .onAppear {
                // Pre-fill fields with current values if not initial setup
                if !isInitialSetup {
                    userName = tripViewModel.currentUser.name
                    userEmail = tripViewModel.currentUser.email
                }
                
                // Ensure Firebase authentication is complete
                ensureAuthentication()
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(isInitialSetup) // Prevent dismissal if it's initial setup
        }
    }
    
    private func ensureAuthentication() {
        isLoading = true
        
        // Sign in anonymously to ensure we have a Firebase user ID
        FirebaseService.shared.signInAnonymously { success, error in
            isLoading = false
            
            if !success {
                // Show auth error section instead of a popup
                authErrorShown = true
                errorMessage = "Failed to set up your account: \(error?.localizedDescription ?? "Unknown error")"
                print("Auth error in UserProfileView: \(errorMessage)")
            }
        }
    }
    
    private func saveProfileLocally() {
        guard !userName.isEmpty else { return }
        
        // Create an updated user with the new name and email
        let updatedUser = User(
            id: tripViewModel.currentUser.id,
            name: userName,
            email: userEmail,
            profileImage: tripViewModel.currentUser.profileImage,
            isClaimed: true
        )
        
        // Update the current user in the view model
        // This will still update locally but Firestore operations might fail
        tripViewModel.updateCurrentUser(updatedUser)
        
        // Small delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            dismiss()
        }
    }
    
    private func saveProfile() {
        guard !userName.isEmpty else { return }
        
        isLoading = true
        
        // Save in the same way as saveProfileLocally
        let updatedUser = User(
            id: tripViewModel.currentUser.id,
            name: userName,
            email: userEmail,
            profileImage: tripViewModel.currentUser.profileImage,
            isClaimed: true
        )
        
        // Update the current user in the view model
        tripViewModel.updateCurrentUser(updatedUser)
        
        // Small delay to allow UI to update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            dismiss()
        }
    }
}

#Preview {
    UserProfileView(tripViewModel: TripViewModel(currentUser: User.create(name: "You", email: "you@example.com")))
} 