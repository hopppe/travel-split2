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
    
    init(hasCompletedSetup: Binding<Bool> = .constant(false)) {
        self._hasCompletedSetup = hasCompletedSetup
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Personal Information")) {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                        .autocapitalization(.words)
                    
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                }
                
                Section(header: Text("Security")) {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)
                }
                
                Section {
                    Button(action: signUp) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Sign Up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isFormValid || isLoading)
                }
            }
            .navigationTitle("Create Account")
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
                
                dismiss()
            } else {
                showError = true
            }
        }
    }
} 