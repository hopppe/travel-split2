//
//  TripExpenseManager.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 4/9/25.
//

import Foundation
import SwiftUI
import Combine

// Manages expense-related operations for trips
class TripExpenseManager {
    // References to shared data
    private let tripViewModel: TripViewModel
    
    // Initialize with reference to TripViewModel
    init(tripViewModel: TripViewModel) {
        self.tripViewModel = tripViewModel
    }
    
    // MARK: - Expense Management
    
    func addExpense(title: String, amount: Double, paidBy: User, splitType: SplitType,
                    customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other,
                    currencyCode: String = "USD", date: Date = Date()) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }

        // Fetch latest currency rates if expense currency differs from trip base currency
        if currencyCode != trip.baseCurrencyCode {
            CurrencyConverterService.shared.fetchLatestRates()
        }

        // Safeguard against using an invalid paidBy user
        // Make sure the paidBy user is in the participant list (and get the latest version)
        if let validPaidBy = trip.participants.first(where: { $0.id == paidBy.id }) {
            var expense: Expense

            // Get current user who is adding this expense
            let addedByUser = tripViewModel.findCurrentUserInTrip()

            switch splitType {
            case .equal:
                // Make sure we're using valid participant references from the trip
                // This prevents issues with stale user references
                expense = Expense.createEqual(
                    title: title,
                    amount: amount,
                    paidBy: validPaidBy,
                    participants: trip.participants,
                    date: date,
                    category: category,
                    currencyCode: currencyCode,
                    addedBy: addedByUser,
                    baseCurrencyCode: trip.baseCurrencyCode
                )
            case .custom:
                guard let shares = customShares, !shares.isEmpty else {
                    tripViewModel.errorMessage = "Custom shares must be provided for custom split"
                    return
                }

                // Validate and update shares to use valid participant references
                var validShares = [ExpenseShare]()
                for share in shares {
                    if let validUser = trip.participants.first(where: { $0.id == share.user.id }) {
                        let validShare = ExpenseShare(user: validUser, amount: share.amount, percentage: share.percentage)
                        validShares.append(validShare)
                    } else {
                        tripViewModel.errorMessage = "Invalid participant in expense share"
                        return
                    }
                }

                expense = Expense.createCustom(
                    title: title,
                    amount: amount,
                    paidBy: validPaidBy,
                    shares: validShares,
                    date: date,
                    category: category,
                    currencyCode: currencyCode,
                    addedBy: addedByUser,
                    baseCurrencyCode: trip.baseCurrencyCode
                )
            }

            // Add expense to trip
            trip.expenses.append(expense)

            // Haptic feedback for successful expense addition
            HapticManager.shared.success()

            // Update trip in the view model
            tripViewModel.updateTrip(trip)
        } else {
            tripViewModel.errorMessage = "Selected payer is not a valid participant in this trip"
            HapticManager.shared.error()
        }
    }
    
    func updateExpense(id: String, title: String, amount: Double, paidBy: User, splitType: SplitType,
                      customShares: [ExpenseShare]? = nil, category: ExpenseCategory = .other,
                      currencyCode: String = "USD", date: Date = Date()) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }

        // Fetch latest currency rates if expense currency differs from trip base currency
        if currencyCode != trip.baseCurrencyCode {
            CurrencyConverterService.shared.fetchLatestRates()
        }

        // Find the expense index in the trip
        guard let expenseIndex = trip.expenses.firstIndex(where: { $0.id == id }) else {
            tripViewModel.errorMessage = "Expense not found"
            return
        }
        
        var updatedExpense: Expense
        
        switch splitType {
        case .equal:
            updatedExpense = Expense.createEqual(
                title: title,
                amount: amount,
                paidBy: paidBy,
                participants: trip.participants,
                date: date,
                category: category,
                currencyCode: currencyCode,
                baseCurrencyCode: trip.baseCurrencyCode
            )
        case .custom:
            guard let shares = customShares, !shares.isEmpty else {
                tripViewModel.errorMessage = "Custom shares must be provided for custom split"
                return
            }
            updatedExpense = Expense.createCustom(
                title: title,
                amount: amount,
                paidBy: paidBy,
                shares: shares,
                date: date,
                category: category,
                currencyCode: currencyCode,
                baseCurrencyCode: trip.baseCurrencyCode
            )
        }

        // Preserve the original ID and addedBy
        let originalExpense = trip.expenses[expenseIndex]
        updatedExpense = Expense(
            id: originalExpense.id,
            title: updatedExpense.title,
            description: updatedExpense.description,
            amount: updatedExpense.amount,
            date: updatedExpense.date,
            category: updatedExpense.category,
            paidBy: updatedExpense.paidBy,
            shares: updatedExpense.shares,
            currencyCode: updatedExpense.currencyCode,
            addedBy: originalExpense.addedBy, // Preserve who originally added this expense
            convertedAmount: updatedExpense.convertedAmount,
            convertedCurrencyCode: updatedExpense.convertedCurrencyCode
        )
        
        // Update the expense
        trip.expenses[expenseIndex] = updatedExpense
        
        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    func deleteExpense(withId id: String) {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            HapticManager.shared.error()
            return
        }

        // Remove the expense
        trip.expenses.removeAll(where: { $0.id == id })

        // Light haptic for deletion
        HapticManager.shared.lightImpact()

        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
    
    // Add a payment between two participants
    func addPayment(title: String, amount: Double, paidBy: User, paidTo: User, currencyCode: String = "USD") {
        guard var trip = tripViewModel.currentTrip else {
            tripViewModel.errorMessage = "No trip selected"
            return
        }

        // Fetch latest currency rates if payment currency differs from trip base currency
        if currencyCode != trip.baseCurrencyCode {
            CurrencyConverterService.shared.fetchLatestRates()
        }

        // Make sure both users are valid participants in the trip
        guard let validPaidBy = trip.participants.first(where: { $0.id == paidBy.id }),
              let validPaidTo = trip.participants.first(where: { $0.id == paidTo.id }) else {
            tripViewModel.errorMessage = "Invalid participants for payment"
            return
        }
        
        // Create a special payment expense that only involves two people
        // In this expense, one person pays and only the other person has a share
        let share = ExpenseShare(user: validPaidTo, amount: amount, percentage: 100.0)

        // Get current user who is adding this payment
        let addedByUser = tripViewModel.findCurrentUserInTrip()

        // Calculate converted amount if currencies differ
        var convertedAmount: Double? = nil
        var convertedCurrencyCode: String? = nil

        if currencyCode != trip.baseCurrencyCode {
            convertedAmount = CurrencyConverterService.shared.convert(
                amount: amount,
                from: currencyCode,
                to: trip.baseCurrencyCode
            )
            convertedCurrencyCode = trip.baseCurrencyCode
        }

        // Create a payment with special metadata to identify it as a payment
        let paymentExpense = Expense(
            id: UUID().uuidString,
            title: title,
            description: "Payment", // This is a special marker we'll use to identify payments
            amount: amount,
            date: Date(),
            category: .other, // Could create a dedicated payment category if desired
            paidBy: validPaidBy,
            shares: [share],
            currencyCode: currencyCode,
            addedBy: addedByUser,
            convertedAmount: convertedAmount,
            convertedCurrencyCode: convertedCurrencyCode
        )
        
        // Add expense to trip
        trip.expenses.append(paymentExpense)

        // Haptic feedback for successful payment recording
        HapticManager.shared.success()

        // Update trip in the view model
        tripViewModel.updateTrip(trip)
    }
} 