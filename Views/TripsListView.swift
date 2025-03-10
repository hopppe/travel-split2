import SwiftUI

struct TripsListView: View {
    @ObservedObject var viewModel: TripViewModel
    @State private var showingNewTripSheet = false
    @State private var showingJoinTripSheet = false
    @State private var newTripName = ""
    @State private var newTripDescription = ""
    @State private var joinTripCode = ""
    @State private var tripToDelete: Trip?
    @State private var showingDeleteConfirmation = false
    @State private var isEditMode: EditMode = .inactive
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if viewModel.trips.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "airplane.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.accentColor)
                        
                        Text("No Trips Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Create a new trip to start tracking expenses with friends")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button(action: {
                            showingNewTripSheet = true
                        }) {
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
                    }
                    .padding()
                } else {
                    // Trip list
                    List {
                        // Recent trips section
                        Section(header: Text("Your Trips")) {
                            ForEach(viewModel.trips) { trip in
                                NavigationLink(destination: TripDetailView(viewModel: viewModel, trip: trip)) {
                                    TripRowView(trip: trip)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        tripToDelete = trip
                                        showingDeleteConfirmation = true
                                    }
                                }
                                .contextMenu {
                                    Button(action: {
                                        // Share trip link
                                        viewModel.selectTrip(trip)
                                        shareTrip()
                                    }) {
                                        Label("Share Trip", systemImage: "square.and.arrow.up")
                                    }
                                    
                                    Divider() // Adds a visual separator
                                    
                                    Button(role: .destructive, action: {
                                        tripToDelete = trip
                                        showingDeleteConfirmation = true
                                    }) {
                                        Label("Delete Trip", systemImage: "trash.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                let tripsToDelete = indexSet.map { viewModel.trips[$0] }
                                if let trip = tripsToDelete.first {
                                    tripToDelete = trip
                                    showingDeleteConfirmation = true
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .environment(\.editMode, $isEditMode)
                }
            }
            .navigationTitle("Travel Split")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                        .disabled(viewModel.trips.isEmpty)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            showingNewTripSheet = true
                        }) {
                            Label("Create New Trip", systemImage: "plus")
                        }
                        
                        Button(action: {
                            showingJoinTripSheet = true
                        }) {
                            Label("Join Trip", systemImage: "person.badge.plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline)
                    }
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
            .alert(item: alertItem) { item in
                Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .confirmationDialog(
                "Delete Trip",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete for Everyone", role: .destructive) {
                    if let trip = tripToDelete {
                        viewModel.deleteTrip(withId: trip.id)
                        tripToDelete = nil
                    }
                }
                
                Button("Cancel", role: .cancel) {
                    tripToDelete = nil
                }
            } message: {
                Text("This will permanently delete the trip for all participants.")
            }
        }
    }
    
    // Create a computed property for showing alerts
    private var alertItem: AlertItem? {
        if let errorMessage = viewModel.errorMessage {
            viewModel.errorMessage = nil // Clear the error after showing
            return AlertItem(
                title: "Error",
                message: errorMessage
            )
        }
        return nil
    }
    
    // Function to share trip invite link
    private func shareTrip() {
        let shareLink = viewModel.generateShareLink()
        let activityVC = UIActivityViewController(
            activityItems: [
                "Join my trip in Travel Split!",
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
}

// MARK: - Supporting Views

// Trip Row View
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
                Text("\(trip.participants.count) participants")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !trip.expenses.isEmpty {
                    Text("$\(getTotalAmount(), specifier: "%.2f")")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Calculate the total amount for the trip
    private func getTotalAmount() -> Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }
}

// Sheet for creating a new trip
struct NewTripSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @Binding var tripName: String
    @Binding var tripDescription: String
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Trip Details")) {
                    TextField("Trip Name", text: $tripName)
                    TextField("Description", text: $tripDescription)
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
                    .disabled(tripName.isEmpty)
                }
            }
        }
    }
    
    private func createTrip() {
        viewModel.createNewTrip(
            name: tripName,
            description: tripDescription
        )
        // Reset fields
        tripName = ""
        tripDescription = ""
        isPresented = false
    }
}

// Sheet for joining a trip
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
    }
    
    private func joinTrip() {
        viewModel.joinTrip(withInviteCode: inviteCode)
        inviteCode = ""
        isPresented = false
    }
}

// Alert item for showing errors
struct AlertItem: Identifiable {
    var id = UUID()
    var title: String
    var message: String
} 