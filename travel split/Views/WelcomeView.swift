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
    @State private var showLanguageSelector = false
    
    // Language manager for localization updates
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                // Subtle language switcher at the top
                HStack {
                    Spacer()
                    Button {
                        showLanguageSelector = true
                    } label: {
                        Text(languageManager.currentLanguage.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // App logo/icon and title
                VStack(spacing: 16) {
                    Image("splitprocopy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                    
                    Text("app_name".localized)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .rtlAwareAlignment(.center)
                }
                .padding(.top, 20)
                
                // Welcome message
                VStack(spacing: 12) {
                    Text("welcome_title".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .rtlAwareAlignment(.center)
                    
                    Text("welcome_subtitle".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .rtlAwareAlignment(.center)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 16) {
                    // Continue without email button and name input
                    if !showNameInput {
                        Button {
                            showNameInput = true
                        } label: {
                            Text("continue_without_email".localized)
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.indigo.opacity(0.1))
                                .foregroundColor(.indigo)
                                .cornerRadius(12)
                        }
                    } else {
                        VStack(spacing: 16) {
                            TextField("enter_your_name".localized, text: $userName)
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .safeRTLTextField()
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
                                    Text("continue".localized)
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
                        Text("sign_in".localized)
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
                        Text("create_account".localized)
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
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showSignUp) {
                SignUpView(hasCompletedSetup: $hasCompletedSetup)
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showLanguageSelector) {
                LanguageSelectorSheet()
                    .environmentObject(languageManager)
                    .interactiveDismissDisabled(false)
            }
        }
        .stableLocalized()
    }
}

// MARK: - Language Selector Sheet
struct LanguageSelectorSheet: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedLanguage: LanguageManager.SupportedLanguage
    
    init() {
        // Initialize with current language to prevent issues during language changes
        _selectedLanguage = State(initialValue: LanguageManager.shared.currentLanguage)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header section
                VStack(spacing: 8) {
                    Text("select_language".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .rtlAwareAlignment(.center)
                        .padding(.top, 20)
                    
                    Text("language".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment(.center)
                }
                .padding(.bottom, 32)
                
                // Language options
                VStack(spacing: 12) {
                    ForEach(LanguageManager.SupportedLanguage.allCases, id: \.rawValue) { language in
                        LanguageOptionRow(
                            language: language,
                            isSelected: selectedLanguage == language
                        ) {
                            // Haptic feedback for selection
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // Update local selection first
                            selectedLanguage = language
                            
                            // Set the language with a slight delay to show selection
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                languageManager.setLanguage(language)
                            }
                            
                            // Dismiss after language change
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            // Sync with current language when sheet appears
            selectedLanguage = languageManager.currentLanguage
        }
    }
}

// MARK: - Language Option Row
struct LanguageOptionRow: View {
    let language: LanguageManager.SupportedLanguage
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Language flag/icon
                Text(languageFlag)
                    .font(.system(size: 24))
                
                // Language details
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.nativeDisplayName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                        .rtlAwareAlignment(.leading)
                    
                    Text(language.displayName)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment(.leading)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.indigo)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var languageFlag: String {
        switch language {
        case .english:
            return "🇺🇸"
        case .arabic:
            return "🇸🇦"
        }
    }
}

#Preview {
    WelcomeView(
        tripViewModel: TripViewModel(currentUser: User(id: "preview", name: "Test", email: "test@example.com")),
        hasCompletedSetup: .constant(false)
    )
    .environmentObject(LanguageManager.shared)
} 
