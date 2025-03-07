import Foundation
import SwiftUI
import Combine

// ViewModel to handle Trip operations
class TripViewModel: ObservableObject {
    @Published var trips: [Trip] = []
    @Published var currentTrip: Trip?
    @Published var currentUser: User
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    // Initialize with the current user
    init(currentUser: User) {
        self.currentUser = currentUser
        // In a real app, you would load trips from persistent storage or server here
        loadTrips()
    }
    
    // MARK: - Trip Management
    
    func loadTrips() {
        // In a real app, this would load from local storage or a server
        // For now, we'll create a sample trip if none exists
        if trips.isEmpty {
            let sampleTrip = Trip.create(
                name: "Weekend Getaway",
                description: "A fun weekend trip with friends",
                creator: currentUser
            )
            trips = [sampleTrip]
        }
    }
    
    func createNewTrip(name: String, description: String) {
        let newTrip = Trip.create(
            name: name,
            description: description,
            creator: currentUser
        )
        trips.append(newTrip)
        currentTrip = newTrip
        
        // In a real app, you would save to storage or server here
    }
    
    func selectTrip(_ trip: Trip) {
        currentTrip = trip
    }
    
    func joinTrip(withInviteCode code: String) {
        guard let trip = trips.first(where: { $0.inviteCode == code }) else {
            errorMessage = "Invalid invite code or trip not found"
            return
        }
        
        // Check if user is already a participant
        if trip.participants.contains(where: { $0.id == currentUser.id }) {
            errorMessage = "You are already a participant in this trip"
            return
        }
        
        // Add user to trip
        var updatedTrip = trip
        updatedTrip.participants.append(currentUser)
        
        // Update trip in array
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = updatedTrip
            currentTrip = updatedTrip
        }
        
        // In a real app, you would save to storage or server here
    }
    
    func addParticipantToCurrentTrip(_ user: User) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Check if user is already a participant
        if trip.participants.contains(where: { $0.id == user.id }) {
            errorMessage = "User is already a participant in this trip"
            return
        }
        
        // Add user to trip
        trip.participants.append(user)
        
        // Update trip in array
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        }
        
        // In a real app, you would save to storage or server here
    }
    
    // MARK: - Expense Management
    
    func addExpenseToCurrentTrip(title: String, amount: Double, paidBy: User, splitType: SplitType, customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        var expense: Expense
        
        switch splitType {
        case .equal:
            expense = Expense.createEqual(
                title: title,
                amount: amount,
                paidBy: paidBy,
                participants: trip.participants,
                category: category
            )
        case .custom:
            guard let shares = customShares, !shares.isEmpty else {
                errorMessage = "Custom shares must be provided for custom split"
                return
            }
            expense = Expense.createCustom(
                title: title,
                amount: amount,
                paidBy: paidBy,
                shares: shares,
                category: category
            )
        }
        
        // Add expense to trip
        trip.expenses.append(expense)
        
        // Update trip in array
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            currentTrip = trip
        }
        
        // In a real app, you would save to storage or server here
    }
    
    func updateExpense(_ expense: Expense) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Find and update the expense
        if let index = trip.expenses.firstIndex(where: { $0.id == expense.id }) {
            trip.expenses[index] = expense
            
            // Update trip in array
            if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
                trips[tripIndex] = trip
                currentTrip = trip
            }
            
            // In a real app, you would save to storage or server here
        } else {
            errorMessage = "Expense not found"
        }
    }
    
    func deleteExpense(withId id: String) {
        guard var trip = currentTrip else {
            errorMessage = "No trip selected"
            return
        }
        
        // Remove the expense
        trip.expenses.removeAll(where: { $0.id == id })
        
        // Update trip in array
        if let tripIndex = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[tripIndex] = trip
            currentTrip = trip
        }
        
        // In a real app, you would save to storage or server here
    }
    
    // MARK: - Balance Calculation
    
    func calculateDebts() -> [Debt] {
        guard let trip = currentTrip else {
            return []
        }
        
        return trip.calculateDebts()
    }
    
    // Generate a share link for the current trip
    func generateShareLink() -> String {
        guard let trip = currentTrip else {
            return ""
        }
        
        // In a real app, this might be a deep link URL
        return "travelsplit://join?code=\(trip.inviteCode)"
    }
}

// Types of expense splits
enum SplitType {
    case equal
    case custom
} 