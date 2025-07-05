//
//  TripsListView.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation
import FirebaseAuth
import TravelSplitModels
import TravelSplitServices
import TravelSplitViewModels
import TravelSplitExtensions

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
    @State private var selectedTripId: String? = nil
    
    // Add a state object for network monitoring
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    // Language manager for localization updates
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Network status indicator
                if !networkMonitor.isConnected {
                    HStack {
                        Image(systemName: "wifi.slash")
                            .foregroundColor(.white)
                        Text("offline_mode".localized)
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .zIndex(2) // Ensure it stays on top
                }
                
                ZStack {
                    // Background color
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()
                    
                    if viewModel.trips.isEmpty {
                        // Display empty state view when there are no trips
                        EmptyTripsView(onCreateTripTapped: {
                            showingNewTripSheet = true
                        }, viewModel: viewModel)
#if !SKIP
                        .accessibilityElement(children: .contain)
#endif
                        .accessibilityLabel("no_trips".localized)
                    } else {
                        // Display list of trips
                        TripListContentView(
                            viewModel: viewModel,
                            onShareTrip: shareTrip,
                            selectedTripId: $selectedTripId
                        )
                    }
                }
            }
            .navigationTitle("groups".localized)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingProfileSheet = true
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "person.circle")
                            // Use Firebase displayName only if available, otherwise use the existing name
                            let displayName = Auth.auth().currentUser?.displayName ?? viewModel.currentUser.name
                            Text(displayName)
                                .lineLimit(1)
                        }
                    }
                    .accessibilityLabel("edit_profile".localized)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    AddMenuButton(
                        onCreateTripTapped: { showingNewTripSheet = true },
                        onJoinTripTapped: { showingJoinTripSheet = true }
                    )
                    .accessibilityLabel("add_options".localized)
                }
            }
            .sheet(isPresented: $showingNewTripSheet) {
                NewTripSheet(
                    viewModel: viewModel,
                    isPresented: $showingNewTripSheet,
                    tripName: $newTripName,
                    tripDescription: $newTripDescription
                )
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingJoinTripSheet) {
                JoinTripSheet(
                    viewModel: viewModel,
                    isPresented: $showingJoinTripSheet,
                    inviteCode: $joinTripCode
                )
                .environmentObject(languageManager)
            }
            .sheet(isPresented: $showingProfileSheet) {
                UserProfileView(tripViewModel: viewModel)
                    .onDisappear {
                        // Ensure we sync the name when returning from profile edits
                        syncUserNameFromFirebase()
                    }
            }
            .alert(item: $alertItem) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: Alert.Button.default(Text("ok".localized))
                )
            }
            .onAppear {
                // Sync the user name from Firebase when the view appears
                syncUserNameFromFirebase()
                
                // Setup notification observer for trip detail navigation
                setupNavigationObserver()
            }
            .onDisappear {
                // Remove notification observer
                NotificationCenter.default.removeObserver(self)
            }
            
            // Navigation link that will be triggered programmatically
            NavigationLink(
                destination: selectedTripDestination,
                isActive: Binding<Bool>(
                    get: { selectedTripId != nil },
                    set: { _ in selectedTripId = nil }
                )
            ) {
                EmptyView()
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
        .forceRTL()
    }
    
    // Computed property for the destination view
    private var selectedTripDestination: some View {
        Group {
            if let tripId = selectedTripId, let trip = viewModel.trips.first(where: { $0.id == tripId }) {
                TripDetailView(viewModel: viewModel, trip: trip)
            } else {
                Text("trip_not_found".localized)
            }
        }
    }
    
    // Setup notification observer for trip detail navigation
    private func setupNavigationObserver() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToTripDetail"),
            object: nil,
            queue: .main
        ) { notification in
            if let userInfo = notification.userInfo,
               let tripId = userInfo["tripId"] as? String {
                // Set the selected trip ID which will trigger the navigation link
                self.selectedTripId = tripId
            }
        }
        
        // Add observer for navigating to expenses after joining via deep link
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("NavigateToExpenses"),
            object: nil,
            queue: .main
        ) { _ in
            // Navigate to the current trip's expenses page
            if let currentTrip = self.viewModel.currentTrip {
                print("Navigating to expenses page for trip: \(currentTrip.name)")
                self.selectedTripId = currentTrip.id
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Synchronizes the user name from Firebase
    private func syncUserNameFromFirebase() {
        if let currentUser = Auth.auth().currentUser {
            // Only update if Firebase actually has a display name (not nil)
            if let firebaseDisplayName = currentUser.displayName {
                // Update the viewModel only if the name is different
                if viewModel.currentUser.name != firebaseDisplayName {
                    var updatedUser = viewModel.currentUser
                    updatedUser.name = firebaseDisplayName
                    viewModel.updateCurrentUser(updatedUser)
                }
            }
        }
    }
    
    /// Shares a trip with other users
    private func shareTrip() {
        guard let trip = viewModel.currentTrip else { return }
        
        // Use the centralized share message generation
        let shareMessage = FirebaseService.shared.generateShareMessage(
            inviteCode: trip.inviteCode,
            tripName: trip.name
        )
        
        let activityVC = UIActivityViewController(
            activityItems: [shareMessage],
            applicationActivities: nil
        )
        
        // Present the share sheet
#if !SKIP
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
#else
        if false {
#endif
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
    @ObservedObject var viewModel: TripViewModel
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            HStack {
                Text("your_groups".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .zIndex(1) // Ensure header is always on top
            
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 72))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                        .padding(.top, 60)
                    
                    Text("no_groups_yet".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .rtlAwareAlignment(HorizontalAlignment.center)
                    
                    Text("create_group_description".localized)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .rtlAwareAlignment(HorizontalAlignment.center)
                    
                    Button(action: onCreateTripTapped) {
                        Label("create_new_group".localized, systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 10)
                    .accessibilityLabel("create_new_group".localized)
                    .accessibilityHint("create_new_group_hint".localized)
                }
                .padding()
                .frame(minHeight: 500) // Ensures there's space to pull
            }
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                print("🔄 REFRESHING TRIPS FROM PULL GESTURE (EMPTY STATE)")
                await refreshData()
            }
        }
    }
    
    // Refresh function using async/await
    private func refreshData() async {
        // Set state to refreshing
        isRefreshing = true
        
        // Create a task that can be awaited
        return await withCheckedContinuation { continuation in
            // Call the view model's refresh method
            DispatchQueue.main.async {
                print("🔄 REFRESHING TRIPS FROM FIREBASE (EMPTY STATE)")
                viewModel.refreshTrips()
                
                // Add a small delay for better user feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isRefreshing = false
                    print("🔄 TRIPS REFRESHED (EMPTY STATE) - Total trips: \(viewModel.trips.count)")
                    continuation.resume()
                }
            }
        }
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
                Label("create_new_group".localized, systemImage: "plus")
            }
            
            Button(action: onJoinTripTapped) {
                Label("join_group".localized, systemImage: "person.badge.plus")
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
    @Binding var selectedTripId: String?
    @State private var tripToLeave: Trip?
    @State private var showingLeaveConfirmation = false
    @State private var showingBalanceWarning = false
    @State private var isRefreshing = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Fixed header
            HStack {
                Text("your_groups".localized)
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                Spacer()
            }
            .background(Color(UIColor.systemGroupedBackground))
            .zIndex(1) // Ensure header is always on top
            
            // Scrollable content with refresh indicator
            List {
                ForEach(viewModel.trips) { trip in
                    NavigationLink(destination: TripDetailView(viewModel: viewModel, trip: trip)) {
                        TripRowView(trip: trip, viewModel: viewModel)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
#if !SKIP
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .swipeActions(edge: .trailing) {
#endif
                        Button(role: .destructive) {
                            tripToLeave = trip
                            if viewModel.canLeaveTrip(trip) {
                                showingLeaveConfirmation = true
                            } else {
                                showingBalanceWarning = true
                            }
                        } label: {
                            Label("leave".localized, systemImage: "door.right.hand.open")
                        }
                        .tint(.red)
#if !SKIP
                    }
                    .contextMenu {
#endif
                        Button(action: {
                            // Share trip link
                            viewModel.selectTrip(trip)
                            onShareTrip()
                        }) {
                            Label("share_group".localized, systemImage: "square.and.arrow.up")
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
                            Label("leave_group".localized, systemImage: "door.right.hand.open")
                                .foregroundColor(.red)
                        }
#if !SKIP
                    }
#endif
                }
            }
            .listStyle(PlainListStyle())
            .background(Color(UIColor.systemGroupedBackground))
            .refreshable {
                print("🔄 REFRESHING TRIPS FROM PULL GESTURE")
                await refreshData()
            }
        }
        .confirmationDialog(
            "leave_group".localized,
            isPresented: $showingLeaveConfirmation,
            titleVisibility: .visible
        ) {
            Button("leave_group".localized, role: .destructive) {
                if let trip = tripToLeave {
                    print("Attempting to leave trip: \(trip.name)")
                    viewModel.leaveTrip(trip: trip)
                    tripToLeave = nil
                }
            }
            
            Button("cancel".localized, role: .cancel) {
                tripToLeave = nil
            }
        } message: {
            if let trip = tripToLeave {
                if viewModel.isLastParticipantInTrip(trip) {
                    Text("leave_group_last_participant".localized)
                } else {
                    Text("leave_group_confirmation".localized)
                }
            } else {
                Text("leave_group_confirmation".localized)
            }
        }
        .alert("cannot_leave_group".localized, isPresented: $showingBalanceWarning) {
            Button("ok".localized, role: .cancel) {
                tripToLeave = nil
            }
        } message: {
            if let trip = tripToLeave {
                Text("outstanding_balance_message".localized(with: viewModel.getUserBalanceString(trip)))
            } else {
                Text("settle_debts_message".localized)
            }
        }
    }
    
    // Refresh function using async/await
    private func refreshData() async {
        // Set state to refreshing
        isRefreshing = true
        
        // Create a task that can be awaited
        return await withCheckedContinuation { continuation in
            // Call the view model's refresh method
            DispatchQueue.main.async {
                print("🔄 REFRESHING TRIPS FROM FIREBASE")
                viewModel.refreshTrips()
                
                // Add a small delay for better user feedback
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isRefreshing = false
                    print("🔄 TRIPS REFRESHED - Total trips: \(viewModel.trips.count)")
                    continuation.resume()
                }
            }
        }
    }
}

/// Individual row displaying trip information
struct TripRowView: View {
    let trip: Trip
    @ObservedObject var viewModel: TripViewModel
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: languageAwareHorizontalAlignment, spacing: 6) {
            HStack {
                Text(trip.name)
                    .font(.headline)
                    .multilineTextAlignment(languageAwareAlignment)
                    .frame(maxWidth: .infinity, alignment: languageManager.isRTL ? .trailing : .leading)
                Spacer(minLength: 0)
            }
            
            HStack {
                if languageManager.isRTL {
                    // RTL layout: balance first, then participants info
                    if !trip.expenses.isEmpty {
                        HStack(spacing: 4) {
                            let balance = viewModel.getUserBalanceInTrip(trip)
                            let balanceText = balance > 0 ? "owed".localized : (balance < 0 ? "owe".localized : "settled".localized)
                            
                            Text("\(trip.baseCurrencySymbol)\(abs(balance), specifier: "%.2f")")
                                .font(.subheadline.bold())
                                .foregroundColor(getBalanceColor(balance))
                                .accessibilityLabel("\(balanceText) \(formatCurrency(abs(balance)))")
                            
                            Text(balanceText)
                                .font(.caption)
                                .foregroundColor(getBalanceColor(balance))
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(trip.participants.count) \("participants".localized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.trailing)
                    
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .accessibilityHidden(true)
                } else {
                    // LTR layout: participants info first, then balance
                    Image(systemName: "person.2.fill")
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                        .accessibilityHidden(true)
                    
                    Text("\(trip.participants.count) \("participants".localized)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if !trip.expenses.isEmpty {
                        HStack(spacing: 4) {
                            let balance = viewModel.getUserBalanceInTrip(trip)
                            let balanceText = balance > 0 ? "owed".localized : (balance < 0 ? "owe".localized : "settled".localized)
                            
                            Text(balanceText)
                                .font(.caption)
                                .foregroundColor(getBalanceColor(balance))
                            
                            Text("\(trip.baseCurrencySymbol)\(abs(balance), specifier: "%.2f")")
                                .font(.subheadline.bold())
                                .foregroundColor(getBalanceColor(balance))
                                .accessibilityLabel("\(balanceText) \(formatCurrency(abs(balance)))")
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, languageManager.layoutDirection)
        .padding(.vertical, 4)
#if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Group: \(trip.name), \(trip.participants.count) \("participants".localized), \(trip.expenses.isEmpty ? "no_expenses".localized : "\(getUserBalanceDescription(trip))")")
#endif
    }
    
    /// Get color based on balance status
    private func getBalanceColor(_ balance: Double) -> Color {
        if balance > 0 {
            return .green
        } else if balance < 0 {
            return .red
        } else {
            return .secondary
        }
    }
    
    /// Get user balance description for accessibility
    private func getUserBalanceDescription(_ trip: Trip) -> String {
        let balance = viewModel.getUserBalanceInTrip(trip)
        let balanceText = balance > 0 ? "you_are_owed".localized : (balance < 0 ? "you_owe".localized : "you_are_settled_up".localized)
        return "\(balanceText) \(formatCurrency(abs(balance)))"
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
#if !SKIP
            .contentShape(Rectangle())
#endif
        }
        .buttonStyle(PlainButtonStyle())
#if !SKIP
        .accessibilityElement(children: .combine)
#endif
        .accessibilityLabel("\(participant.name)\(isSelected ? ", \("selected".localized)" : "")")
        .accessibilityHint(isSelected ? "double_tap_to_remove".localized : "double_tap_to_add".localized)
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
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("group_details".localized)) {
                    TextField("group_name".localized, text: $tripName)
                        .safeRTLTextField()
                        .accessibilityLabel("group_name".localized)
                    
                    TextField("description_optional".localized, text: $tripDescription)
                        .safeRTLTextField()
                        .accessibilityLabel("description_optional".localized)
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
                            Text(showingParticipantsSection ? "hide_participants".localized : "add_participants".localized)
                                .foregroundColor(.accentColor)
                                .rtlAwareAlignment()
                            
                            Spacer()
                            
                            Image(systemName: showingParticipantsSection ? "chevron.up" : "chevron.down")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                if showingParticipantsSection {
                    // Previous participants suggestions
                    if !previousParticipants.isEmpty {
                        Section(header: Text("previous_participants".localized)) {
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
                    
                    Section(header: Text("add_participants".localized)) {
                        ForEach(0..<participants.count, id: \.self) { index in
                            VStack(spacing: 12) {
                                TextField("name".localized, text: $participants[index].name)
                                    .safeRTLTextField()
                                    .padding(Edge.Set.vertical, 4)
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
                                , alignment: Alignment.bottom
                            )
                        }
                        
                        Button(action: {
                            participants.append(TripParticipantEntry())
                        }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("add_more".localized)
                                    .foregroundColor(.accentColor)
                                    .rtlAwareAlignment()
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section {
                    Text(showingParticipantsSection 
                         ? "group_creation_description_with_participants".localized
                         : "group_creation_description_without_participants".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment()
                }
            }
            .navigationTitle("new_group".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("create".localized) {
                        createTrip()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
        .forceRTL()
    }
    
    // Form validation
    private var isFormValid: Bool {
        // Valid if trip name is not empty AND either:
        // 1. Participants section is not shown, OR
        // 2. At least one manually added participant has a non-empty name, OR
        // 3. At least one previous participant is selected
        let hasValidName = !tripName.isEmpty
        let participantsValid = !showingParticipantsSection || 
                               (!participants.isEmpty && participants.allSatisfy { !$0.name.isEmpty }) || 
                               !selectedPreviousParticipants.isEmpty
        
        return hasValidName && participantsValid
    }
    
    // Toggle the selection of a previous participant
    private func toggleParticipantSelection(_ participant: User) {
        if selectedPreviousParticipants.contains(participant.id) {
            selectedPreviousParticipants.remove(participant.id)
        } else {
            selectedPreviousParticipants.insert(participant.id)
        }
    }
    
    /// Creates a new trip with the entered details
    private func createTrip() {
        // Process participants if section is shown
        var initialParticipants: [User] = []
        
        if showingParticipantsSection {
            // Filter out empty entries
            let validParticipants = participants.filter { !$0.name.isEmpty }
            
            // Create unclaimed participants from manual entries
            for entry in validParticipants {
                initialParticipants.append(User.createUnclaimed(
                    name: entry.name,
                    email: ""
                ))
            }
            
            // Add selected previous participants
            for participantId in selectedPreviousParticipants {
                if let participant = previousParticipants.first(where: { $0.id == participantId }) {
                    initialParticipants.append(participant)
                }
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
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("enter_invite_code_header".localized)) {
                    TextField("invite_code".localized, text: $inviteCode)
                                                        .autocapitalization(TextInputAutocapitalization.none)
                        .disableAutocorrection(true)
                        .safeRTLTextField()
                        .accessibilityLabel("group_invite_code".localized)
                }
                
                Section {
                    Text("join_group_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment()
                }
            }
            .navigationTitle("join_group_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("join".localized) {
                        joinTrip()
                    }
                    .disabled(inviteCode.isEmpty)
                }
            }
        }
        .forceRTL()
        .fullScreenCover(isPresented: $viewModel.showParticipantClaimingView) {
            if let trip = viewModel.currentTrip, !viewModel.potentialClaimableParticipants.isEmpty {
                ParticipantClaimView(
                    viewModel: viewModel,
                    potentialMatches: viewModel.potentialClaimableParticipants,
                    trip: trip
                )
                .environmentObject(languageManager)
            }
        }
    }
    
    /// Joins a trip with the entered invite code
    private func joinTrip() {
        viewModel.joinTrip(withInviteCode: inviteCode) { success in
            // If join was successful and not showing claim view, navigate to trip detail
            if success && !viewModel.showParticipantClaimingView {
                if let trip = viewModel.currentTrip {
                    // Post notification to navigate to the trip detail
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToTripDetail"),
                        object: nil,
                        userInfo: ["tripId": trip.id]
                    )
                }
                
                inviteCode = ""
                isPresented = false
            }
            // Only dismiss this sheet if we're not showing the claim view
            else if !viewModel.showParticipantClaimingView {
                inviteCode = ""
                isPresented = false
            }
        }
    }
} 