import SwiftUI

struct WelcomeView: View {
    @StateObject private var authService = AuthenticationService.shared
    @ObservedObject var tripViewModel: TripViewModel
    @Binding var hasCompletedSetup: Bool
    @State private var showSignIn = false
    @State private var showSignUp = false
    @State private var showNameInput = false
    @State private var userName = ""
    @State private var isNameValid = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // App logo/icon and title
                VStack(spacing: 16) {
                    Image("splitprocopy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    Text("EquiSplit")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 60)
                
                // Welcome message
                VStack(spacing: 12) {
                    Text("Split group expenses")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Easily track and split costs with friends on your next adventure")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Continue without email button and name input
                    if !showNameInput {
                        Button {
                            showNameInput = true
                        } label: {
                            Text("Continue without email")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo.opacity(0.1))
                                .foregroundColor(.indigo)
                                .cornerRadius(12)
                        }
                    } else {
                        VStack(spacing: 16) {
                            TextField("Enter your name", text: $userName)
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .onChange(of: userName) { newValue in
                                    isNameValid = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                }
                            
                            Button {
                                if isNameValid && !isLoading {
                                    // Show loading indicator
                                    isLoading = true
                                    
                                    // Explicitly create an anonymous account
                                    FirebaseService.shared.signInAnonymously { success, error in
                                        isLoading = false
                                        
                                        if success {
                                            print("Successfully created anonymous account")
                                            // Update the user's name
                                            tripViewModel.currentUser.name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                                            
                                            // Save to UserDefaults to ensure persistence
                                            UserDefaults.standard.set(userName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "user_name")
                                            
                                            // Complete setup and transition to main UI
                                            hasCompletedSetup = true
                                        } else {
                                            print("Failed to create anonymous account: \(error?.localizedDescription ?? "unknown error")")
                                            // Proceed anyway with local user
                                            tripViewModel.currentUser.name = userName.trimmingCharacters(in: .whitespacesAndNewlines)
                                            
                                            // Save to UserDefaults to ensure persistence
                                            UserDefaults.standard.set(userName.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "user_name")
                                            
                                            // Complete setup and transition to main UI
                                            hasCompletedSetup = true
                                        }
                                    }
                                }
                            } label: {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.indigo)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                } else {
                                    Text("Continue")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(isNameValid ? Color.indigo : Color.gray)
                                        .foregroundColor(.white)
                                        .cornerRadius(12)
                                }
                            }
                            .disabled(!isNameValid || isLoading)
                        }
                    }
                    
                    // Sign in button
                    Button {
                        showSignIn = true
                        showNameInput = false // Reset the name input state
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    
                    // Sign up button
                    Button {
                        showSignUp = true
                        showNameInput = false // Reset the name input state
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.indigo.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .sheet(isPresented: $showSignIn) {
                SignInView(hasCompletedSetup: $hasCompletedSetup)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(hasCompletedSetup: $hasCompletedSetup)
            }
        }
    }
}

#Preview {
    WelcomeView(
        tripViewModel: TripViewModel(currentUser: User(id: "preview", name: "Test", email: "test@example.com")),
        hasCompletedSetup: .constant(false)
    )
} 
