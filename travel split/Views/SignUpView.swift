import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    
    @Binding var hasCompletedSetup: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var name = ""
    @State private var isLoading = false
    @State private var showError = false
    
    // Language manager for localization updates
    @EnvironmentObject var languageManager: LanguageManager
    
    init(hasCompletedSetup: Binding<Bool> = .constant(false)) {
        self._hasCompletedSetup = hasCompletedSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("profile".localized)) {
                    TextField("name".localized, text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                        .safeRTLTextField()
                    
                    TextField("email".localized, text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .safeRTLTextField()
                }
                
                Section(header: Text("password".localized)) {
                    SecureField("password".localized, text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("password".localized, text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section {
                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("create_account".localized)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("create_account".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
            .alert("error".localized, isPresented: $showError) {
                Button("ok".localized) { }
            } message: {
                Text(authService.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        !name.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        email.contains("@") &&
        email.contains(".")
    }
    
    private func signUp() {
        guard isFormValid else { return }
        
        isLoading = true
        
        authService.signUp(email: email, password: password, name: name) { success, error in
            isLoading = false
            
            if success {
                self.hasCompletedSetup = true
                
                // Post notification that authentication changed
                NotificationCenter.default.post(name: NSNotification.Name("AuthenticationDidChange"), object: nil)
                
                dismiss()
            } else {
                showError = true
            }
        }
    }
} 