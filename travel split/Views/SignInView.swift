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
    
    init(hasCompletedSetup: Binding<Bool> = .constant(false)) {
        self._hasCompletedSetup = hasCompletedSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                    
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }
                
                Section {
                    Button(action: signIn) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Sign In")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
                
                Section {
                    Button("Forgot Password?") {
                        showResetPassword = true
                    }
                }
            }
            .navigationTitle("Sign In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(authService.errorMessage ?? "An unknown error occurred")
            }
            .alert("Reset Password", isPresented: $showResetPassword) {
                TextField("Email", text: $email)
                Button("Cancel", role: .cancel) { }
                Button("Send Reset Link") {
                    resetPassword()
                }
            } message: {
                Text("Enter your email address to receive a password reset link.")
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