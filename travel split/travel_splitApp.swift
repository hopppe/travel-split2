//
//  travel_splitApp.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
// Import FirebaseCore in the main app file too
import FirebaseCore
import FirebaseAuth
import Combine

@main
struct TravelSplitApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Add a flag to control whether we allow anonymous authentication
    @AppStorage("allowAnonymousAuth") private var allowAnonymousAuth = true
    
    // Track if this is the first launch
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    
    // For tracking sign out
    @State private var userHasSignedOut = false
    
    // Language manager for localization
    @StateObject private var languageManager = LanguageManager.shared
    
    // Initialize Firebase first
    init() {
        // Ensure anonymous auth is allowed by default
        UserDefaults.standard.register(defaults: ["allowAnonymousAuth": true])
        
        // Note: Firebase is configured in AppDelegate, don't configure it again here
        print("TravelSplitApp initialized")
        
        // Start network monitoring
        _ = NetworkMonitor.shared
        
        // Don't access Auth directly in the initializer; use a slight delay to ensure
        // the AppDelegate has had time to configure Firebase
        DispatchQueue.main.async { [self] in
            // Now it's safe to access Auth
            if let user = Auth.auth().currentUser {
                print("Firebase user already exists at app startup: \(user.uid)")
                print("User is anonymous: \(user.isAnonymous)")
                
                // If the user has an email, they're a real user (not anonymous)
                if let email = user.email, !email.isEmpty {
                    print("User has email: \(email), marking as real user")
                    // Disable anonymous auth since we have a real user
                    allowAnonymousAuth = false
                } else {
                    // Ensure anonymous auth is enabled for anonymous users
                    allowAnonymousAuth = true
                }
                
                // Store values in UserDefaults, but don't modify self directly here
                UserDefaults.standard.set(true, forKey: "hasCompletedSetup")
                
                // Update the UI on the main thread
                DispatchQueue.main.async {
                    // Ensure hasCompletedSetup is true since we have a Firebase user
                    hasCompletedSetup = true
                }
            } else {
                // No Firebase user at startup - show welcome screen
                print("No Firebase user at startup, showing welcome screen")
                // Ensure anonymous auth is enabled for new users
                allowAnonymousAuth = true
                UserDefaults.standard.set(true, forKey: "allowAnonymousAuth")
                
                DispatchQueue.main.async {
                    hasCompletedSetup = false
                }
            }
        }
    }
    
    // Create the view model with current user
    @StateObject private var tripViewModel = TripViewModel(
        currentUser: TripViewModel.loadOrCreateUser(),
        trips: []
    )
    
    // For handling deep links
    @Environment(\.openURL) private var openURL
    @State private var selectedInviteCode: String?
    @State private var inviteCode: String = ""
    @State private var showJoinTripSheet = false
    @State private var showClaimSheet = false
    @State private var showUserProfileSetup = false
    
    var body: some Scene {
        WindowGroup {
            if !hasCompletedSetup || userHasSignedOut {
                // Show welcome screen for new users or after sign out
                WelcomeView(tripViewModel: tripViewModel, hasCompletedSetup: $hasCompletedSetup)
                    .tint(.indigo) // Add consistent tint color
                    .environmentObject(languageManager) // Inject language manager
                    .withRTLSupport() // Apply RTL support
                    .onAppear {
                        // Reset the sign out flag when the welcome view appears
                        userHasSignedOut = false
                    }
            } else {
                // Show main app interface for existing users
                TripsListView(viewModel: tripViewModel)
                    .tint(.indigo) // Set app accent color
                    .environmentObject(languageManager) // Inject language manager
                    .withRTLSupport() // Apply RTL support
                    .onAppear {
                        // Set up appearance
                        configureAppearance()
                        
                        // Check for deep links
                        handleStartupDeepLink()
                        
                        // Set up observer for claiming view
                        setupTripViewModelObservers()
                    }
                    .onOpenURL { url in
                        // Handle deep link when app is already running
                        handleDeepLink(url)
                    }
                    .sheet(isPresented: $showJoinTripSheet) {
                        JoinTripWithCodeView(viewModel: tripViewModel, inviteCode: inviteCode)
                            .environmentObject(languageManager)
                            .withRTLSupport()
                    }
                    .sheet(isPresented: $showClaimSheet, onDismiss: {
                        // Reset the view model's flag when the sheet is dismissed
                        print("Claim sheet dismissed, resetting showParticipantClaimingView")
                        tripViewModel.showParticipantClaimingView = false
                    }) {
                        ClaimViewCoordinator(
                            viewModel: tripViewModel,
                            showClaimSheet: $showClaimSheet
                        )
                        .environmentObject(languageManager)
                        .withRTLSupport()
                    }
            }
        }
    }
    
    // MARK: - View Model Observers
    
    // Set up observers for the view model properties
    private func setupTripViewModelObservers() {
        // Add observer for sign out notifications
        NotificationCenter.default.addObserver(forName: .userDidSignOut, object: nil, queue: .main) { [self] _ in
            print("Received user sign out notification")
            // First trigger the UI transition
            self.userHasSignedOut = true
            
            // Then reset the trip view model with a slight delay to avoid conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Reset the trip view model
                self.tripViewModel.reset()
            }
        }
        
        // Add observer for stopping all listeners (before account deletion)
        NotificationCenter.default.addObserver(forName: .stopAllListeners, object: nil, queue: .main) { [self] _ in
            print("Received stop all listeners notification")
            self.tripViewModel.stopAllListeners()
        }
        
        // Add observer for account deletion notifications
        NotificationCenter.default.addObserver(forName: .userAccountDeleted, object: nil, queue: .main) { [self] _ in
            print("Received user account deletion notification")
            // First trigger the UI transition back to welcome screen
            self.userHasSignedOut = true
            self.hasCompletedSetup = false
            
            // Then reset the trip view model with a slight delay to avoid conflicts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // Reset the trip view model completely
                self.tripViewModel.reset()
            }
        }
        
        // Add observer for trips updated notification
        NotificationCenter.default.addObserver(forName: NSNotification.Name("TripsUpdated"), object: nil, queue: .main) { [self] _ in
            print("Received trips updated notification - refreshing trips")
            DispatchQueue.main.async {
                // Force refresh all trips from Firebase
                self.tripViewModel.refreshTrips()
            }
        }
        
        // Add observer for the showParticipantClaimingView property
        tripViewModel.$showParticipantClaimingView
            .sink { showClaiming in
                print("Observer detected showParticipantClaimingView changed to: \(showClaiming)")
                if showClaiming {
                    print("ViewModel says to show participant claiming view")
                    self.tripViewModel.logParticipantClaimingState()
                    DispatchQueue.main.async {
                        self.showClaimSheet = true
                    }
                }
            }
            .store(in: &tripViewModel.cancellables)
        
        // Also monitor potentialClaimableParticipants changes
        tripViewModel.$potentialClaimableParticipants
            .sink { participants in
                print("Observer detected potentialClaimableParticipants changed, count: \(participants.count)")
            }
            .store(in: &tripViewModel.cancellables)
    }
    
    // Handle incoming URLs (both Universal Links and custom URL schemes)
    private func handleIncomingURL(_ url: URL) {
        print("Received URL in app: \(url)")
        print("URL scheme: \(url.scheme ?? "none")")
        print("URL host: \(url.host ?? "none")")
        print("URL path: \(url.path)")
        
        // Extract invite code from URL components
        var extractedInviteCode: String? = nil
        
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: true) {
            // Handle Universal Links (https://equisplit.ingenuitylabs.net/join/ABC123)
            if url.scheme == "https" && url.host == "equisplit.ingenuitylabs.net" {
                let pathComponents = components.path.components(separatedBy: "/")
                if pathComponents.count >= 3 && pathComponents[1] == "join" {
                    let inviteCode = pathComponents[2]
                    print("Found invite code in Universal Link path: \(inviteCode)")
                    extractedInviteCode = inviteCode
                }
            }
            // Handle custom URL scheme (travelsplit://join?code=ABC123)
            else if url.scheme == "travelsplit" {
                // Check for invite code in query parameters
                if let codeItem = components.queryItems?.first(where: { $0.name == "code" }),
                   let inviteCode = codeItem.value {
                    print("Found invite code in custom scheme query parameters: \(inviteCode)")
                    extractedInviteCode = inviteCode
                }
                
                // Also check path components for custom scheme (travelsplit://join/ABC123)
                if extractedInviteCode == nil {
                    let pathComponents = components.path.components(separatedBy: "/")
                    if pathComponents.count >= 2 && pathComponents[1] == "join" && pathComponents.count >= 3 {
                        let inviteCode = pathComponents[2]
                        print("Found invite code in custom scheme path: \(inviteCode)")
                        extractedInviteCode = inviteCode
                    }
                }
            }
        }
        
        guard let inviteCode = extractedInviteCode else {
            print("Could not parse invite code from URL: \(url)")
            return
        }
        
        print("Processing invite code: \(inviteCode)")
        
        // Auto-join the trip directly
        tripViewModel.autoJoinTrip(withInviteCode: inviteCode) { success in
            if success {
                print("Successfully joined trip via deep link - navigating to expenses page")
                // Successfully joined trip - navigate to the trip's expenses page
                DispatchQueue.main.async {
                    // The trip should now be set as currentTrip in the view model
                    // The main TripsListView will automatically navigate to TripDetailView
                    // and we want to show the expenses tab (tab 0)
                    NotificationCenter.default.post(name: NSNotification.Name("NavigateToExpenses"), object: nil)
                }
            } else {
                // Check if we need to show the claim sheet instead
                if self.tripViewModel.showParticipantClaimingView {
                    // Set showClaimSheet to true to ensure the claim view appears
                    DispatchQueue.main.async {
                        print("Setting showClaimSheet to true from handleIncomingURL")
                        self.selectedInviteCode = inviteCode
                        self.inviteCode = inviteCode
                        self.showClaimSheet = true
                    }
                }
                // We no longer show the join sheet even if auto-join fails for other reasons
            }
        }
    }
    
    // Configure global appearance settings
    private func configureAppearance() {
        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithDefaultBackground()
        
        // Apply appearance to all navigation bars
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    // Handle startup deep link
    private func handleStartupDeepLink() {
        // Check if we have a deep link waiting to be processed from startup
        if let url = delegate.launchURL {
            print("Processing deep link from startup: \(url)")
            handleIncomingURL(url)
        }
    }
    
    // Handle deep link
    private func handleDeepLink(_ url: URL) {
        print("Processing deep link while app is running: \(url)")
        handleIncomingURL(url)
    }
}

// A simple view for joining a trip with a code
struct JoinTripWithCodeView: View {
    @ObservedObject var viewModel: TripViewModel
    var inviteCode: String
    @State private var manualCode: String
    @Environment(\.dismiss) var dismiss
    
    init(viewModel: TripViewModel, inviteCode: String) {
        self.viewModel = viewModel
        self.inviteCode = inviteCode
        // Use the provided invite code as the initial value
        self._manualCode = State(initialValue: inviteCode)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("enter_invite_code".localized)
                        .padding(.vertical, 8)
                    
                    TextField("invite_code".localized, text: $manualCode)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.vertical, 8)
                    
                    Button("join_trip".localized) {
                        joinTrip()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .disabled(manualCode.isEmpty)
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("join_trip".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(content: {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            })
        }
    }
    
    private func joinTrip() {
        viewModel.joinTrip(withInviteCode: manualCode, completion: nil)
        // We delay the dismiss to allow the error message to be shown if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}
