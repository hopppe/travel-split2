import SwiftUI

struct SignInView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authService = AuthenticationService.shared
    
    @Binding var hasCompletedSetup: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var showResetPassword = false
    
    // Language manager for localization updates
    @EnvironmentObject var languageManager: LanguageManager
    
    init(hasCompletedSetup: Binding<Bool> = .constant(false)) {
        self._hasCompletedSetup = hasCompletedSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("email".localized, text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .safeRTLTextField()
                    
                    SecureField("password".localized, text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("sign_in".localized)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
                
                Section {
                    Button("reset_password".localized) {
                        showResetPassword = true
                    }
                }
            }
            .navigationTitle("sign_in".localized)
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
            .alert("reset_password".localized, isPresented: $showResetPassword) {
                TextField("email".localized, text: $email)
                    .safeRTLTextField()
                Button("cancel".localized, role: .cancel) { }
                Button("send_reset_link".localized) {
                    resetPassword()
                }
            } message: {
                Text("enter_email_reset".localized)
            }
        }
    }
    
    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty
    }
    
    private func signIn() {
        guard isFormValid else { return }
        
        isLoading = true
        
        authService.signIn(email: email, password: password) { success, error in
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
    
    private func resetPassword() {
        authService.resetPassword(email: email) { success, error in
            if success {
                showResetPassword = false
            } else {
                showError = true
            }
        }
    }
} 