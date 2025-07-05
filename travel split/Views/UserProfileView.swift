import SwiftUI
import FirebaseAuth
import TravelSplitModels
import TravelSplitServices
import TravelSplitViewModels
import TravelSplitExtensions

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager
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
                Section(header: Text("profile".localized)) {
                    TextField("name".localized, text: $userName)
                        .textContentType(.name)
                        .autocapitalization(TextInputAutocapitalization.words)
                        .safeRTLTextField()
                    
                    if !isAnonymousUser {
                        TextField("email".localized, text: $userEmail)
                            .textContentType(.emailAddress)
                                                    .autocapitalization(TextInputAutocapitalization.none)
                        .keyboardType(UIKeyboardType.emailAddress)
                            .disabled(true)
                            .safeRTLTextField()
                    }
                    
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .frame(maxWidth: .infinity)
                    } else {
                        Button(action: saveProfile) {
                            Text(isAnonymousUser ? "save_name".localized : "update_profile".localized)
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(userName.isEmpty || isLoading)
                    }
                }
                
                if isAnonymousUser {
                    Section(header: Text("account".localized)) {
                        Button("sign_in".localized) {
                            showSignIn = true
                        }
                        
                        Button("create_account".localized) {
                            showSignUp = true
                        }
                        
                        Button("delete_all_data".localized, role: .destructive) {
                            showDeleteAccountConfirmation = true
                        }
                        .disabled(isDeletingAccount)
                    }
                } else {
                    Section(header: Text("account_settings".localized)) {
                        Button("sign_out".localized, role: .destructive) {
                            showSignOutConfirmation = true
                        }
                        
                        Button("delete_account".localized, role: .destructive) {
                            showDeleteAccountConfirmation = true
                        }
                        .disabled(isDeletingAccount)
                    }
                }
                
                // Language section
                Section(header: Text("language".localized)) {
                    HStack {
                        Text("select_language".localized)
                            .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
                        
                        Spacer()
                        
                        Picker("", selection: $languageManager.currentLanguage) {
                            ForEach(LanguageManager.SupportedLanguage.allCases, id: \.self) { language in
                                Text(language.nativeDisplayName).tag(language)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .rtlHStack()
                }
                
                // Feedback section
                Section(header: Text("feedback".localized)) {
                    VStack(alignment: languageAwareHorizontalAlignment, spacing: 8) {
                        Text("feedback_message".localized)
                            .font(.body)
                            .foregroundColor(.primary)
                            .rtlAwareAlignment()
                        
                        Button("ethan@ingenuitylabs.net") {
                            // Create mailto URL
                            if let url = URL(string: "mailto:ethan@ingenuitylabs.net?subject=EquiSplit App Feedback") {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.body)
                        .foregroundColor(.blue)
                        .rtlAwareAlignment()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isInitialSetup ? "welcome_to_equisplit".localized : "settings".localized)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if !isInitialSetup {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("cancel".localized) {
                            dismiss()
                        }
                    }
                }
            }
            .sheet(isPresented: $showSignIn) {
                                            SignInView(hasCompletedSetup: .constant(true))
                                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(hasCompletedSetup: .constant(true))
                    .environmentObject(languageManager)
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
            .forceRTL()
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized, role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("sign_out_confirmation".localized, isPresented: $showSignOutConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button("sign_out".localized, role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("are_you_sure_sign_out".localized)
            }
            .alert(isAnonymousUser ? "delete_all_data".localized : "delete_account".localized, isPresented: $showDeleteAccountConfirmation) {
                Button("cancel".localized, role: .cancel) { }
                Button(isAnonymousUser ? "delete_all_data".localized : "delete_account".localized, role: .destructive) {
                    performDeleteAccount()
                }
            } message: {
                if isAnonymousUser {
                    Text("delete_data_confirmation".localized)
                } else {
                    Text("delete_account_confirmation".localized)
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
                } else if userName.isEmpty || userName == "user" {
                    // Only update if current name is empty or default
                    if tripViewModel.currentUser.name != "user" {
                        userName = tripViewModel.currentUser.name
                    }
                }
                // Otherwise keep existing name in the field
            } else {
                // Anonymous user
                isAnonymousUser = true
                
                // For anonymous users, preserve their custom name if they set one
                if userName.isEmpty || userName == "user" {
                    // If current profile name is empty or default "user",
                    // check if the model has a custom name
                    if tripViewModel.currentUser.name != "user" {
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
    UserProfileView(tripViewModel: TripViewModel(currentUser: User.create(name: "user", email: "user@example.com")))
} 