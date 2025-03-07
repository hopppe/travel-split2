//
//  BalancesViews.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// MARK: - Main Balance View

/// Main view for the trip balances tab showing debts and settlements
struct BalancesView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if let trip = viewModel.currentTrip, !trip.expenses.isEmpty {
                let debts = viewModel.calculateDebts()
                
                if debts.isEmpty {
                    SettledUpView()
                } else {
                    BalancesContentView(trip: trip, debts: debts, viewModel: viewModel)
                }
            } else {
                NoExpensesView()
            }
        }
    }
}

// MARK: - State Views

/// View shown when all participants are settled (no debts)
struct SettledUpView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.green)
                .accessibilityHidden(true)
            
            Text("All Settled Up!")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text("Everyone has paid their fair share")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("All settled up. Everyone has paid their fair share.")
    }
}

/// View shown when there are no expenses to calculate balances
struct NoExpensesView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.5))
                .accessibilityHidden(true)
            
            Text("No Expenses to Calculate")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text("Add expenses to see who owes what")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No expenses to calculate. Add expenses to see who owes what.")
    }
}

// MARK: - Balance Content View

/// Main content view displaying balances and debts
struct BalancesContentView: View {
    let trip: Trip
    let debts: [Debt]
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        List {
            // User balance overview section
            Section(header: Text("Your Balance")) {
                UserBalanceRow(
                    user: viewModel.currentUser,
                    balance: calculateUserBalance(for: viewModel.currentUser.id),
                    isCurrentUser: true
                )
            }
            
            // Debts section
            Section(header: Text("Who Owes What")) {
                ForEach(debts, id: \.id) { debt in
                    DebtRowView(debt: debt)
                }
            }
            
            // Summary section
            Section(header: Text("Summary")) {
                TotalSummaryView(trip: trip)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    /// Calculate the total balance for a specific user
    private func calculateUserBalance(for userId: String) -> Double {
        var balance: Double = 0
        
        // Add money owed to the user
        for debt in debts where debt.to.id == userId {
            balance += debt.amount
        }
        
        // Subtract money owed by the user
        for debt in debts where debt.from.id == userId {
            balance -= debt.amount
        }
        
        return balance
    }
}

// MARK: - Row Views

/// Row displaying a user's balance
struct UserBalanceRow: View {
    let user: User
    let balance: Double
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            // Profile image or initial
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(String(user.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(isCurrentUser ? "You" : user.name)
                    .font(.headline)
                
                Text(balanceDescription)
                    .font(.subheadline)
                    .foregroundColor(balanceColor)
            }
            
            Spacer()
            
            Text(formattedBalance)
                .font(.headline)
                .foregroundColor(balanceColor)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isCurrentUser ? "You" : user.name) \(balanceDescription) \(formattedBalance)")
    }
    
    /// Description of the balance (owes, receives, settled)
    private var balanceDescription: String {
        if balance > 0 {
            return "will receive"
        } else if balance < 0 {
            return "owes others"
        } else {
            return "is settled up"
        }
    }
    
    /// Color based on balance status
    private var balanceColor: Color {
        if balance > 0 {
            return .green
        } else if balance < 0 {
            return .red
        } else {
            return .secondary
        }
    }
    
    /// Formatted currency amount
    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: abs(balance))) ?? "$0.00"
    }
}

/// Row displaying a debt between two users
struct DebtRowView: View {
    let debt: Debt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.from.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .accessibilityHidden(true)
                    
                    Text("owes")
                        .font(.caption)
                    
                    Text(debt.to.name)
                        .font(.caption.bold())
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedAmount)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(debt.from.name) owes \(debt.to.name) \(formattedAmount)")
    }
    
    /// Formatted currency amount
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: debt.amount)) ?? String(format: "$%.2f", debt.amount)
    }
}

/// Summary view showing trip totals
struct TotalSummaryView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Trip Cost")
                    .font(.headline)
                Spacer()
                Text(formattedTotalCost)
                    .font(.headline)
            }
            
            HStack {
                Text("Average Per Person")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(formattedAveragePerPerson)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Total trip cost: \(formattedTotalCost), Average per person: \(formattedAveragePerPerson)")
    }
    
    // MARK: - Helper Properties and Methods
    
    /// Formatted total trip cost
    private var formattedTotalCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: totalTripCost())) ?? String(format: "$%.2f", totalTripCost())
    }
    
    /// Formatted average cost per person
    private var formattedAveragePerPerson: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        return formatter.string(from: NSNumber(value: averagePerPerson())) ?? String(format: "$%.2f", averagePerPerson())
    }
    
    /// Calculate total trip cost
    private func totalTripCost() -> Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }
    
    /// Calculate average cost per person
    private func averagePerPerson() -> Double {
        let total = totalTripCost()
        let count = trip.participants.count
        return count > 0 ? total / Double(count) : 0
    }
} 