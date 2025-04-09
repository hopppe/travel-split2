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
            .navigationTitle("Groups")
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
        
        // Get the deep link URL from FirebaseService
        let deepLinkURL = FirebaseService.shared.createDeepLink(inviteCode: trip.inviteCode)
        
        // Create a simple share message with just the essentials
        let shareMessage = """
        Join my group '\(trip.name)' in Travel Split!
        
        Link: \(deepLinkURL)
        Code: \(trip.inviteCode)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareMessage],
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
        
        // Use the current trip's currency symbol if available, otherwise default to USD
        let currencySymbol = viewModel.currentTrip?.baseCurrencySymbol ?? "$"
        formatter.currencySymbol = currencySymbol
        
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)\(amount)"
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
            
            Text("No Groups Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a new group to start tracking expenses with friends")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button(action: onCreateTripTapped) {
                Label("Create New Group", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 10)
            .accessibilityLabel("Create new group")
            .accessibilityHint("Creates a new group to track expenses")
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
                Label("Create New Group", systemImage: "plus")
            }
            
            Button(action: onJoinTripTapped) {
                Label("Join Group", systemImage: "person.badge.plus")
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
    @State private var tripToLeave: Trip?
    @State private var showingLeaveConfirmation = false
    @State private var showingBalanceWarning = false
    
    var body: some View {
        List {
            Section(header: Text("Your Groups")) {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(destination: TripDetailView(viewModel: viewModel, trip: trip)) {
                        TripRowView(trip: trip)
                    }
                    .swipeActions(edge: .trailing) {
                        Button("Leave", role: .destructive) {
                            tripToLeave = trip
                            if viewModel.canLeaveTrip(trip) {
                                showingLeaveConfirmation = true
                            } else {
                                showingBalanceWarning = true
                            }
                        }
                    }
                    .contextMenu {
                        Button(action: {
                            // Share trip link
                            viewModel.selectTrip(trip)
                            onShareTrip()
                        }) {
                            Label("Share Group", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider() // Visual separator
                        
                        Button(role: .destructive, action: {
                            tripToLeave = trip
                            if viewModel.canLeaveTrip(trip) {
                                showingLeaveConfirmation = true
                            } else {
                                showingBalanceWarning = true
                            }
                        }) {
                            Label("Leave Group", systemImage: "door.right.hand.open")
                                .foregroundColor(.red)
                        }
                    }
                    .accessibilityHint("Navigate to trip details")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .confirmationDialog(
            "Leave Group",
            isPresented: $showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                if let trip = tripToLeave {
                    viewModel.leaveTrip(trip: trip)
                    tripToLeave = nil
                }
            }
            
            Button("Cancel", role: .cancel) {
                tripToLeave = nil
            }
        } message: {
            Text("You will be removed from this group but other participants will still have access.")
        }
        .alert("Cannot Leave Group", isPresented: $showingBalanceWarning) {
            Button("OK", role: .cancel) {
                tripToLeave = nil
            }
        } message: {
            if let trip = tripToLeave {
                Text("You have an outstanding balance of \(viewModel.getUserBalanceString(trip)). You must settle all debts before leaving the group.")
            } else {
                Text("You must settle all debts before leaving the group.")
            }
        }
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
                    Text("\(trip.baseCurrencySymbol)\(getTotalAmount(), specifier: "%.2f")")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                        .accessibilityLabel("Total \(formatCurrency(getTotalAmount()))")
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Group: \(trip.name), \(trip.participants.count) participants, \(trip.expenses.isEmpty ? "No expenses" : "Total \(formatCurrency(getTotalAmount()))")")
    }
    
    /// Calculate the total amount for the trip
    private func getTotalAmount() -> Double {
        return trip.expenses.reduce(0) { total, expense in
            let expenseCurrency = expense.currencyCode ?? "USD"
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency, 
                to: trip.baseCurrencyCode
            )
            return total + convertedAmount
        }
    }
    
    /// Format currency for accessibility labels
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = trip.baseCurrencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(trip.baseCurrencySymbol)\(amount)"
    }
}

// MARK: - Sheet Views

/// Struct to manage participant entry data
struct TripParticipantEntry: Identifiable {
    var id = UUID()
    var name: String = ""
    var email: String = ""
}

/// View for displaying and selecting a previous participant
struct TripPreviousParticipantView: View {
    let participant: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(participant.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        )
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                            .offset(x: 5, y: 5)
                    }
                }
                
                Text(participant.name)
                    .font(.caption)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(participant.name)\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "Double tap to remove" : "Double tap to add")
    }
}

/// Sheet for creating a new trip
struct NewTripSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @Binding var tripName: String
    @Binding var tripDescription: String
    
    @State private var participants: [TripParticipantEntry] = []
    @State private var showingParticipantsSection = false
    @State private var previousParticipants: [User] = []
    @State private var selectedPreviousParticipants = Set<String>()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Group Details")) {
                    TextField("Group Name", text: $tripName)
                        .accessibilityLabel("Group name")
                    
                    TextField("Description (Optional)", text: $tripDescription)
                        .accessibilityLabel("Group description")
                }
                
                // Participants section that can be toggled
                Section {
                    Button(action: {
                        if !showingParticipantsSection {
                            // Add one empty participant entry when toggling on
                            if participants.isEmpty {
                                participants = [TripParticipantEntry()]
                            }
                            // Load previous participants
                            previousParticipants = viewModel.getPreviousParticipants()
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
                    // Previous participants suggestions
                    if !previousParticipants.isEmpty {
                        Section(header: Text("Previous Participants")) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(previousParticipants) { participant in
                                        TripPreviousParticipantView(
                                            participant: participant,
                                            isSelected: selectedPreviousParticipants.contains(participant.id),
                                            onTap: {
                                                toggleParticipantSelection(participant)
                                            }
                                        )
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .padding(.horizontal, -16) // Extend beyond section edges
                        }
                    }
                    
                    Section(header: Text("Add Participants")) {
                        ForEach(0..<participants.count, id: \.self) { index in
                            VStack(spacing: 12) {
                                TextField("Name", text: $participants[index].name)
                                    .padding(.vertical, 4)
                                
                                TextField("Email (optional)", text: $participants[index].email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding(.vertical, 4)
                            }
                            .padding(.bottom, 8)
                            .overlay(
                                // Only add bottom border if not the last item
                                Group {
                                    if index < participants.count - 1 {
                                        Rectangle()
                                            .frame(height: 0.5)
                                            .foregroundColor(Color.gray.opacity(0.3))
                                            .offset(y: 12)
                                    }
                                }
                                , alignment: .bottom
                            )
                        }
                        
                        Button(action: {
                            participants.append(TripParticipantEntry())
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
                         ? "Add participants now or you can add them later after creating the group."
                         : "Enter details for your new group. You can add participants and expenses after creating the group.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("New Group")
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
    
    // Toggle the selection of a previous participant
    private func toggleParticipantSelection(_ participant: User) {
        if selectedPreviousParticipants.contains(participant.id) {
            selectedPreviousParticipants.remove(participant.id)
            
            // Remove from the participants list if they were added
            participants.removeAll { entry in
                // Match by name since we don't have the ID in TripParticipantEntry
                return entry.name == participant.name && entry.email == participant.email
            }
        } else {
            selectedPreviousParticipants.insert(participant.id)
            
            // Add to the participants list
            let entry = TripParticipantEntry(name: participant.name, email: participant.email)
            participants.append(entry)
        }
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
        selectedPreviousParticipants.removeAll()
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
                        .accessibilityLabel("Group invite code")
                }
                
                Section {
                    Text("Enter the code shared with you to join an existing group. This code is found in the group's share menu.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Join Group")
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