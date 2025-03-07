//
//  travel_splitApp.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
// Import FirebaseCore in the main app file too
import FirebaseCore

@main
struct TravelSplitApp: App {
    // Register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Create user from saved preferences or default
    @StateObject private var tripViewModel = TripViewModel(
        currentUser: TripViewModel.loadOrCreateUser()
    )
    
    // For handling deep links
    @Environment(\.openURL) private var openURL
    @State private var selectedInviteCode: String?
    @State private var showJoinTripSheet = false
    @State private var showClaimSheet = false
    @State private var showUserProfileSetup = false
    
    var body: some Scene {
        WindowGroup {
            TripsListView(viewModel: tripViewModel)
                .tint(.indigo) // Set app accent color
                .onOpenURL { url in
                    // Handle deep links
                    handleIncomingURL(url)
                }
                .onAppear {
                    // Set up appearance
                    configureAppearance()
                    
                    // No need to call FirebaseApp.configure() here anymore
                    // It's now handled by the AppDelegate
                    
                    // Initialize Firebase service
                    _ = FirebaseService.shared
                    
                    // Check if we need to show user profile setup
                    // This will be true for first-time users
                    if tripViewModel.currentUser.name == "You" && 
                       tripViewModel.currentUser.email == "you@example.com" {
                        showUserProfileSetup = true
                    }
                }
                .sheet(isPresented: $showJoinTripSheet) {
                    JoinTripWithCodeView(viewModel: tripViewModel, inviteCode: selectedInviteCode ?? "")
                }
                .sheet(isPresented: $showClaimSheet) {
                    if let trip = tripViewModel.currentTrip, !tripViewModel.potentialClaimableParticipants.isEmpty {
                        ParticipantClaimView(
                            viewModel: tripViewModel,
                            potentialMatches: tripViewModel.potentialClaimableParticipants,
                            trip: trip
                        )
                    }
                }
                .sheet(isPresented: $showUserProfileSetup) {
                    UserProfileView(tripViewModel: tripViewModel)
                }
                .onChange(of: tripViewModel.showParticipantClaimingView) { oldValue, newValue in
                    // Show claim sheet when view model signals it's needed
                    if newValue {
                        showClaimSheet = true
                        // Reset flag after showing
                        DispatchQueue.main.async {
                            tripViewModel.showParticipantClaimingView = false
                        }
                    }
                }
        }
    }
    
    // Handle incoming URLs 
    private func handleIncomingURL(_ url: URL) {
        // Extract code from URL - we won't use Dynamic Links now
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems,
           let codeItem = queryItems.first(where: { $0.name == "code" }),
           let inviteCode = codeItem.value {
            
            selectedInviteCode = inviteCode
            showJoinTripSheet = true
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
                    Text("Enter the invite code to join a trip.")
                        .padding(.vertical, 8)
                    
                    TextField("Invite Code", text: $manualCode)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .padding(.vertical, 8)
                    
                    Button("Join Trip") {
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
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func joinTrip() {
        viewModel.joinTrip(withInviteCode: manualCode)
        // We delay the dismiss to allow the error message to be shown if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if viewModel.errorMessage == nil {
                dismiss()
            }
        }
    }
}
