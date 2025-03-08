//
//  TripsListView.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation

// MARK: - Main Trip List View
/// The main view that displays all trips and provides options to create or join trips
struct TripsListView: View {
    @ObservedObject var viewModel: TripViewModel
    @State private var showingNewTripSheet = false
    @State private var showingJoinTripSheet = false
    @State private var showingProfileSheet = false
    @State private var newTripName = ""
    @State private var newTripDescription = ""
    @State private var joinTripCode = ""
    @State private var alertItem: AlertItem?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.trips.isEmpty {
                    // Display empty state view when there are no trips
                    EmptyTripsView(onCreateTripTapped: {
                        showingNewTripSheet = true
                    })
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("No trips")
                } else {
                    // Display list of trips
                    TripListContentView(
                        viewModel: viewModel,
                        onShareTrip: shareTrip
                    )
                }
            }
            .navigationTitle("Travel Split")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingProfileSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                            Text(viewModel.currentUser.name)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityLabel("Edit profile")
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddMenuButton(
                        onCreateTripTapped: { showingNewTripSheet = true },
                        onJoinTripTapped: { showingJoinTripSheet = true }
                    )
                    .accessibilityLabel("Add options")
                }
            }
            .sheet(isPresented: $showingNewTripSheet) {
                NewTripSheet(
                    viewModel: viewModel,
                    isPresented: $showingNewTripSheet,
                    tripName: $newTripName,
                    tripDescription: $newTripDescription
                )
            }
            .sheet(isPresented: $showingJoinTripSheet) {
                JoinTripSheet(
                    viewModel: viewModel,
                    isPresented: $showingJoinTripSheet,
                    inviteCode: $joinTripCode
                )
            }
            .sheet(isPresented: $showingProfileSheet) {
                UserProfileView(tripViewModel: viewModel)
            }
            .alert(item: $alertItem) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
        .onReceive(viewModel.$errorMessage) { errorMessage in
            if let errorMessage = errorMessage {
                self.alertItem = AlertItem(
                    title: "Error",
                    message: errorMessage
                )
                
                // Clear the error after we've handled it
                DispatchQueue.main.async {
                    viewModel.errorMessage = nil
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Shares a trip with other users
    private func shareTrip() {
        guard let trip = viewModel.currentTrip else { return }
        
        let shareLink = viewModel.generateShareLink()
        
        // Create a more detailed share message
        let shareMessage = """
        Join my trip '\(trip.name)' in Travel Split!
        
        • \(trip.participants.count) participants
        • \(trip.expenses.count) expenses
        • Total: \(formatCurrency(trip.expenses.reduce(0) { $0 + $1.amount }))
        
        Use this link to join and view details:
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [
                shareMessage,
                shareLink
            ],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    /// Formats a number as currency
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // Default to USD
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Supporting Models

/// Alert item for showing errors
struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
}

// MARK: - Empty State View

/// View shown when there are no trips
struct EmptyTripsView: View {
    let onCreateTripTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "airplane.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text("No Trips Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a new trip to start tracking expenses with friends")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: onCreateTripTapped) {
                Label("Create New Trip", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .accessibilityLabel("Create new trip")
            .accessibilityHint("Creates a new trip to track expenses")
        }
        .padding()
    }
}

// MARK: - UI Components

/// Menu button for creating or joining trips
struct AddMenuButton: View {
    let onCreateTripTapped: () -> Void
    let onJoinTripTapped: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onCreateTripTapped) {
                Label("Create New Trip", systemImage: "plus")
            }
            
            Button(action: onJoinTripTapped) {
                Label("Join Trip", systemImage: "person.badge.plus")
            }
        } label: {
            Image(systemName: "plus")
                .font(.headline)
        }
    }
}

/// Content view showing the list of trips
struct TripListContentView: View {
    @ObservedObject var viewModel: TripViewModel
    let onShareTrip: () -> Void
    
    var body: some View {
        List {
            Section(header: Text("Your Trips")) {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(destination: TripDetailView(viewModel: viewModel, trip: trip)) {
                        TripRowView(trip: trip)
                    }
                    .contextMenu {
                        Button(action: {
                            // Share trip link
                            viewModel.selectTrip(trip)
                            onShareTrip()
                        }) {
                            Label("Share Trip", systemImage: "square.and.arrow.up")
                        }
                    }
                    .accessibilityHint("Navigate to trip details")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

/// Individual row displaying trip information
struct TripRowView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trip.name)
                .font(.headline)
            
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .accessibilityHidden(true)
                
                Text("\(trip.participants.count) participants")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !trip.expenses.isEmpty {
                    Text("$\(getTotalAmount(), specifier: "%.2f")")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .accessibilityLabel("Total \(formatCurrency(getTotalAmount()))")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trip: \(trip.name), \(trip.participants.count) participants, \(trip.expenses.isEmpty ? "No expenses" : "Total \(formatCurrency(getTotalAmount()))")")
    }
    
    /// Calculate the total amount for the trip
    private func getTotalAmount() -> Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// Format currency for accessibility labels
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // Default to USD
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
}

// MARK: - Sheet Views

/// Sheet for creating a new trip
struct NewTripSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @Binding var tripName: String
    @Binding var tripDescription: String
    
    @State private var participants: [ParticipantEntry] = []
    @State private var showingParticipantsSection = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Trip Name", text: $tripName)
                        .accessibilityLabel("Trip name")
                    
                    TextField("Description (Optional)", text: $tripDescription)
                        .accessibilityLabel("Trip description")
                }
                
                // Participants section that can be toggled
                Section {
                    Button(action: {
                        if !showingParticipantsSection {
                            // Add one empty participant entry when toggling on
                            if participants.isEmpty {
                                participants = [ParticipantEntry()]
                            }
                            showingParticipantsSection = true
                        } else {
                            showingParticipantsSection = false
                        }
                    }) {
                        HStack {
                            Text(showingParticipantsSection ? "Hide Participants" : "Add Participants")
                                .foregroundColor(.accentColor)
                            
                            Spacer()
                            
                            Image(systemName: showingParticipantsSection ? "chevron.up" : "chevron.down")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                if showingParticipantsSection {
                    Section(header: Text("Participants")) {
                        ForEach(0..<participants.count, id: \.self) { index in
                            VStack(spacing: 12) {
                                TextField("Name", text: $participants[index].name)
                                    .padding(.vertical, 4)
                                
                                TextField("Email (optional)", text: $participants[index].email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(.vertical, 4)
                                
                                if participants.count > 1 && index < participants.count - 1 {
                                    Divider()
                                        .padding(.vertical, 4)
                                }
                            }
                        }
                        
                        Button(action: {
                            participants.append(ParticipantEntry())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Add More")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Text(showingParticipantsSection 
                         ? "Add participants now or you can add them later after creating the trip."
                         : "Enter details for your new trip. You can add participants and expenses after creating the trip.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createTrip()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }
    
    // Form validation
    private var isFormValid: Bool {
        !tripName.isEmpty && (!showingParticipantsSection || participants.allSatisfy { !$0.name.isEmpty })
    }
    
    /// Creates a new trip with the entered details
    private func createTrip() {
        // Process participants if section is shown
        var initialParticipants: [User] = []
        
        if showingParticipantsSection {
            // Filter out empty entries
            let validParticipants = participants.filter { !$0.name.isEmpty }
            
            // Create unclaimed participants
            initialParticipants = validParticipants.map { entry in
                User.createUnclaimed(
                    name: entry.name,
                    email: entry.email
                )
            }
        }
        
        // Create the trip with initial participants
        viewModel.createNewTrip(
            name: tripName,
            description: tripDescription,
            initialParticipants: initialParticipants
        )
        
        // Reset fields
        tripName = ""
        tripDescription = ""
        participants = []
        showingParticipantsSection = false
        isPresented = false
    }
}

/// Sheet for joining an existing trip
struct JoinTripSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @Binding var inviteCode: String
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Enter Invite Code")) {
                    TextField("Invite Code", text: $inviteCode)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .accessibilityLabel("Trip invite code")
                }
                
                Section {
                    Text("Enter the code shared with you to join an existing trip. This code is found in the trip's share menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        joinTrip()
                    }
                    .disabled(inviteCode.isEmpty)
                }
            }
        }
        .fullScreenCover(isPresented: $viewModel.showParticipantClaimingView) {
            if let trip = viewModel.currentTrip, !viewModel.potentialClaimableParticipants.isEmpty {
                ParticipantClaimView(
                    viewModel: viewModel,
                    potentialMatches: viewModel.potentialClaimableParticipants,
                    trip: trip
                )
            }
        }
        .onChange(of: viewModel.showParticipantClaimingView) { newValue in
            // When the participant claim view is dismissed, also dismiss this sheet
            if !newValue {
                inviteCode = ""
                isPresented = false
            }
        }
    }
    
    /// Joins a trip with the entered invite code
    private func joinTrip() {
        viewModel.joinTrip(withInviteCode: inviteCode)
        
        // Only dismiss this sheet if we're not showing the claim view
        if !viewModel.showParticipantClaimingView {
            inviteCode = ""
            isPresented = false
        }
    }
} 