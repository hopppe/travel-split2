import SwiftUI

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    @ObservedObject var tripViewModel: TripViewModel
    
    @State private var userName = ""
    @State private var userEmail = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var isInitialSetup: Bool
    
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
                    
                    // Only show email field if user is authenticated
                    if authService.isAuthenticated {
                        TextField("Email", text: $userEmail)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .disabled(authService.isAuthenticated)
                    }
                }
                
                if !authService.isAuthenticated {
                    Section {
                        Button("Sign In") {
                            showSignIn = true
                        }
                        
                        Button("Create Account") {
                            showSignUp = true
                        }
                    }
                } else {
                    Section {
                        Button(action: saveProfile) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            } else {
                                Text("Save Profile")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(userName.isEmpty || isLoading)
                    }
                    
                    Section {
                        Button("Sign Out", role: .destructive) {
                            authService.signOut()
                        }
                    }
                }
            }
            .navigationTitle(isInitialSetup ? "Welcome to Travel Split" : "Edit Profile")
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
                SignInView()
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView()
            }
            .onAppear {
                // Pre-fill fields with current values
                userName = tripViewModel.currentUser.name
                userEmail = tripViewModel.currentUser.email
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .interactiveDismissDisabled(isInitialSetup)
        }
    }
    
    private func saveProfile() {
        guard !userName.isEmpty else { return }
        
        isLoading = true
        
        // Update the user in the trip view model
        let updatedUser = User(id: authService.currentUser?.id ?? UUID().uuidString,
                             name: userName,
                             email: userEmail,
                             profileImage: nil,
                             isClaimed: true)
        
        // Update the user in the view model
        tripViewModel.updateUser(updatedUser)
        
        // Save to UserDefaults
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