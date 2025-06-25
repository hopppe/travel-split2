//
//  BalanceBreakdownSheet.swift
//  Split Pro
//
//  Created by Ethan Hoppe on 4/8/25.
//
//  A sheet that shows the detailed breakdown of a debt balance,
//  including contributing expenses, person totals, and simplification explanation.

import SwiftUI
import Foundation

// MARK: - Balance Breakdown Sheet
struct BalanceBreakdownSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    @Binding var isPresented: Bool
    
    let debt: Debt
    
    // MARK: - Models
    struct PersonTotal {
        let user: User
        let amount: Double
    }
    
    var body: some View {
        Form {
            // Balance Summary Section
            Section {
                HStack {
                    Text(balanceSummaryText)
                        .font(.headline)
                        .fontWeight(.bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.vertical, 8)
                
                HStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(debt.from.name.prefix(1)))
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        )
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 30, height: 30)
                        .overlay(
                            Text(String(debt.to.name.prefix(1)))
                                .font(.subheadline)
                                .foregroundColor(.accentColor)
                        )
                        
                    Spacer()
                    
                    Text(formatCurrency(debt.amount))
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
            }
            
            // Contributing Expenses Section
            if !contributingExpenses.isEmpty {
                Section(header: Text("Contributing Expenses")) {
                    ForEach(contributingExpenses) { expense in
                        ExpenseBreakdownCard(
                            expense: expense,
                            fromUser: debt.from,
                            toUser: debt.to,
                            currencySymbol: viewModel.currentTrip?.baseCurrencySymbol ?? "$"
                        )
                    }
                }
            }
            
            // Person Totals Section
            Section(header: Text("Person Totals")) {
                ForEach(getPersonTotals(), id: \.user.id) { total in
                    HStack {
                        Text(total.user.name)
                            .fontWeight(.medium)
                        Spacer()
                        Text(formatCurrency(total.amount))
                            .foregroundColor(total.amount >= 0 ? Color.green : Color.red)
                            .fontWeight(.semibold)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // Simplification Section
            Section(header: Text("How We Simplified")) {
                Text(simplificationExplanation)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Balance Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    isPresented = false
                }
            }
        }
    }
    
    // MARK: - Data-related computed properties
    
    /// List of expenses that contributed to this balance
    var contributingExpenses: [Expense] {
        guard let trip = viewModel.currentTrip else { return [] }
        
        // Check if this is a user viewing their own balance
        let currentUserId = viewModel.currentUser.id
        let isViewingOwnBalance = debt.from.id == currentUserId || debt.to.id == currentUserId
        
        if isViewingOwnBalance {
            // For user's own balance, show all expenses they're involved in
            return trip.expenses.filter { expense in
                // Show expense if user is either a payer or a participant
                expense.paidBy.id == currentUserId || 
                expense.shares.contains { $0.user.id == currentUserId }
            }.sorted(by: { $0.date > $1.date }) // Sort by date (newest first)
        } else {
            // For debts between other participants, show expenses involving both
            return trip.expenses.filter { expense in
                // Check if this expense involves both users
                let involvesBoth = expense.shares.contains { $0.user.id == debt.from.id } &&
                                   expense.shares.contains { $0.user.id == debt.to.id }
                
                return involvesBoth
            }.sorted(by: { $0.date > $1.date }) // Sort by date (newest first)
        }
    }
    
    /// Summary text describing the balance
    var balanceSummaryText: String {
        let amount = abs(debt.amount)
        let formattedAmount = formatCurrency(amount)
        
        // For all cases, show who owes what to whom
        return "\(debt.from.name) owes \(formattedAmount) to \(debt.to.name)"
    }
    
    /// Explanation of how the debt was calculated and simplified
    var simplificationExplanation: String {
        guard let trip = viewModel.currentTrip else { return "" }
        
        // Get the raw balances before simplification
        var balances: [String: Double] = [:]
        
        // Calculate what each person has paid and what they owe
        for expense in trip.expenses {
            let expenseCurrency = expense.currencyCode ?? "USD"
            
            // Convert expense amount to base currency
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            // Add the amount to the payer
            balances[expense.paidBy.id, default: 0] += convertedAmount
            
            // Subtract the amount from each participant based on their share
            for share in expense.shares {
                // Convert share amount to base currency
                let convertedShareAmount = CurrencyConverterService.shared.convert(
                    amount: share.amount,
                    from: expenseCurrency,
                    to: trip.baseCurrencyCode
                )
                balances[share.user.id, default: 0] -= convertedShareAmount
            }
        }
        
        // Start building the explanation
        var explanation = "Before simplification:\n"
        
        // Add all participants' balances
        for participant in trip.participants.sorted(by: { $0.name < $1.name }) {
            let balance = balances[participant.id, default: 0]
            explanation += "• \(participant.name) had a net balance of \(formatCurrency(balance))\n"
        }
        
        // Get all the simplified debts
        let allDebts = viewModel.calculateDebts()
        
        // Add list of all debts after simplification
        explanation += "\nAfter simplification:\n"
        
        if allDebts.isEmpty {
            explanation += "Everyone is settled up! No payments are needed.\n"
        } else {
            for debt in allDebts {
                explanation += "• \(debt.from.name) owes \(formatCurrency(debt.amount)) to \(debt.to.name)\n"
            }
        }
        
        // Add information about this specific debt
        if !allDebts.isEmpty {
            explanation += "\nThe highlighted balance is part of this simplified solution, where \(debt.from.name) owes \(formatCurrency(debt.amount)) to \(debt.to.name).\n"
        }
        
        // Final note
        explanation += "\nThis represents the most efficient way for everyone to settle up."
        
        return explanation
    }
    
    /// Format currency amount
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = viewModel.currentTrip?.baseCurrencySymbol ?? "$"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    /// Get person totals related to the debt
    func getPersonTotals() -> [PersonTotal] {
        guard let trip = viewModel.currentTrip else { return [] }
        
        var totals: [String: Double] = [:]
        
        // Check if this is a user viewing their own balance
        let currentUserId = viewModel.currentUser.id
        let isViewingOwnBalance = debt.from.id == currentUserId || debt.to.id == currentUserId
        
        // Determine which expenses to consider
        let expensesToConsider = isViewingOwnBalance
            ? trip.expenses.filter { expense in
                // For user balance, include all expenses the user is involved in
                expense.paidBy.id == currentUserId || 
                expense.shares.contains { $0.user.id == currentUserId }
            }
            : contributingExpenses
        
        // Calculate totals from relevant expenses
        for expense in expensesToConsider {
            // Add what was paid
            let expenseCurrency = expense.currencyCode ?? "USD"
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            
            totals[expense.paidBy.id, default: 0] += convertedAmount
            
            // Subtract what was owed
            for share in expense.shares {
                let convertedAmount = CurrencyConverterService.shared.convert(
                    amount: share.amount,
                    from: expenseCurrency,
                    to: trip.baseCurrencyCode
                )
                totals[share.user.id, default: 0] -= convertedAmount
            }
        }
        
        // Always show all participants with non-zero balances
        return trip.participants
            .filter { participant in
                // Only include participants with non-zero balances
                let total = totals[participant.id, default: 0]
                return abs(total) > 0.01
            }
            .map { participant in
                PersonTotal(user: participant, amount: totals[participant.id, default: 0])
            }
            .sorted { abs($0.amount) > abs($1.amount) } // Sort by balance magnitude
    }
}

// MARK: - Expense Breakdown Card
struct ExpenseBreakdownCard: View {
    let expense: Expense
    let fromUser: User
    let toUser: User
    let currencySymbol: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Expense header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: expense.category.icon)
                        .foregroundColor(.accentColor)
                    
                    Text(expense.title)
                        .font(.headline)
                }
                
                Spacer()
                
                Text(formatDate(expense.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Expense amount and payer
            HStack {
                Text("Paid by: \(expense.paidBy.name)")
                    .font(.subheadline)
                
                Spacer()
                
                Text("Total: \(formatCurrency(expense.amount))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            Divider()
                .padding(.vertical, 4)
            
            // Expense breakdown
            VStack(alignment: .leading, spacing: 4) {
                // For current user view, we need to show their contribution
                // and also any relevant shares from other users
                let relevantShares = getRelevantShares()
                
                // Show what each person paid/owed
                ForEach(relevantShares, id: \.user.id) { share in
                    HStack {
                        Text(share.user.name)
                            .font(.footnote)
                        
                        Spacer()
                        
                        Text(formatCurrency(share.amount))
                            .font(.footnote)
                            .foregroundColor(getAmountColor(for: share.user, amount: share.amount))
                    }
                }
                
                // Show what the payer contributed (positive amount)
                if isUserInvolved(expense.paidBy) {
                    HStack {
                        Text("\(expense.paidBy.name) paid")
                            .font(.footnote)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text("+\(formatCurrency(expense.amount))")
                            .font(.footnote)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // Helper methods
    
    /// Get the relevant expense shares to display
    private func getRelevantShares() -> [ExpenseShare] {
        // Always show all shares for consistency
        return expense.shares
    }
    
    /// Check if a user is involved in this expense breakdown
    private func isUserInvolved(_ user: User) -> Bool {
        // Always return true to show all users' contributions
        return true
    }
    
    /// Check if this is showing a current user's balance
    private func isCurrentUserView() -> Bool {
        // This method is now unused but kept for backward compatibility
        return true
    }
    
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currencySymbol)\(amount)"
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func getAmountColor(for user: User, amount: Double) -> Color {
        // If this is what a user owes, it's negative (red)
        // If this is what a user paid, it's positive (green)
        if amount > 0 {
            return .green
        } else if amount < 0 {
            return .red
        }
        return .primary
    }
} 