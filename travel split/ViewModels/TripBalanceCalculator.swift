//
//  TripBalanceCalculator.swift
//  free split
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation

// Manages balance calculations and currency operations for trips
class TripBalanceCalculator {
    // References to shared data
    private let tripViewModel: TripViewModel
    
    // Initialize with reference to TripViewModel
    init(tripViewModel: TripViewModel) {
        self.tripViewModel = tripViewModel
    }
    
    // MARK: - Balance Calculation
    
    // Calculate all debts in the current trip
    func calculateDebts() -> [Debt] {
        guard let trip = tripViewModel.currentTrip else {
            return []
        }
        
        return trip.calculateDebts()
    }
    
    // Helper function to get a user's current balance in a trip
    func getUserBalance(in trip: Trip) -> Double {
        // Find current user's representation in this trip
        let currentUser = tripViewModel.currentUser
        let userIds = [currentUser.id]
        let claimedParticipants = trip.participants.filter { $0.claimedByUserId == currentUser.id }
        let userParticipantIds = userIds + claimedParticipants.map { $0.id }
        
        // Calculate balance for all user's identities in this trip
        var balance: Double = 0
        
        for expense in trip.expenses {
            // Get expense amount converted to the trip's base currency
            let expenseCurrency = expense.currencyCode ?? trip.baseCurrencyCode
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            // Check if user paid for this expense
            if userParticipantIds.contains(expense.paidBy.id) {
                // User paid, so they're owed money
                balance += convertedAmount
            }
            
            // Check how much user owes for this expense
            for share in expense.shares {
                if userParticipantIds.contains(share.user.id) {
                    // Convert the share amount to trip's base currency
                    let convertedShareAmount = CurrencyConverterService.shared.convert(
                        amount: share.amount,
                        from: expenseCurrency,
                        to: trip.baseCurrencyCode
                    )
                    
                    // User has a share in this expense, reduce balance
                    balance -= convertedShareAmount
                }
            }
        }
        
        return balance
    }
    
    // Check if user can leave a trip (has zero balance)
    func canLeaveTrip(_ trip: Trip) -> Bool {
        let balance = getUserBalance(in: trip)
        return abs(balance) < 0.01 // Using a small epsilon for floating-point comparison
    }
    
    // Check if a specific participant has a zero balance
    func isParticipantBalanceZero(_ participant: User, in trip: Trip) -> Bool {
        // Calculate what this participant has paid and what they owe
        var balance: Double = 0
        
        for expense in trip.expenses {
            // Get expense amount converted to the trip's base currency
            let expenseCurrency = expense.currencyCode ?? trip.baseCurrencyCode
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            // Check if participant paid for this expense
            if expense.paidBy.id == participant.id {
                // Participant paid, so they're owed money
                balance += convertedAmount
            }
            
            // Check how much participant owes for this expense
            for share in expense.shares {
                if share.user.id == participant.id {
                    // Convert the share amount to trip's base currency
                    let convertedShareAmount = CurrencyConverterService.shared.convert(
                        amount: share.amount,
                        from: expenseCurrency,
                        to: trip.baseCurrencyCode
                    )
                    
                    // Participant has a share in this expense, reduce balance
                    balance -= convertedShareAmount
                }
            }
        }
        
        return abs(balance) < 0.01 // Using a small epsilon for floating-point comparison
    }
    
    // Get user's balance in a trip with proper formatting
    func getUserBalanceString(_ trip: Trip) -> String {
        let balance = getUserBalance(in: trip)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = trip.baseCurrencySymbol
        return formatter.string(from: NSNumber(value: abs(balance))) ?? "\(trip.baseCurrencySymbol)\(abs(balance))"
    }
    
    // MARK: - Currency Management
    
    // Update the base currency for the trip
    func updateBaseCurrency(to currencyCode: String) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }
        
        // Update the base currency
        trip.baseCurrencyCode = currencyCode
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Get the current base currency code
    func getBaseCurrencyCode() -> String {
        return tripViewModel.currentTrip?.baseCurrencyCode ?? "USD"
    }
    
    // Get the current base currency symbol
    func getBaseCurrencySymbol() -> String {
        return tripViewModel.currentTrip?.baseCurrencySymbol ?? "$"
    }
} 