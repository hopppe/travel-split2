//
//  ExpensesViews.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// MARK: - Expenses List View

/// Main view for the expenses tab displaying either an empty state or expenses list
struct ExpensesListView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    let onAddExpense: () -> Void
    let onEditExpense: (Expense) -> Void
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if trip.expenses.isEmpty {
                EmptyExpensesView(onAddExpense: onAddExpense)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("No expenses")
            } else {
                ExpensesContentView(
                    viewModel: viewModel,
                    trip: trip,
                    onAddExpense: onAddExpense,
                    onEditExpense: onEditExpense
                )
            }
        }
    }
}

// MARK: - Empty State View

/// View shown when there are no expenses yet
struct EmptyExpensesView: View {
    let onAddExpense: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text("No Expenses Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text("Add your first expense to start tracking")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onAddExpense) {
                Label("Add Expense", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 8)
            .accessibilityLabel("Add your first expense")
            .accessibilityHint("Creates a new expense for this trip")
        }
        .padding()
    }
}

// MARK: - Expenses Content View

/// View displaying the list of expenses grouped by date
struct ExpensesContentView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    let onAddExpense: () -> Void
    let onEditExpense: (Expense) -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 16) {
                    // Simple flat list of expenses without date grouping
                    ForEach(trip.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        ExpenseRowView(
                            viewModel: viewModel,
                            expense: expense,
                            onEdit: {
                                onEditExpense(expense)
                            }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 80) // Space for FAB
            }
            
            // Floating action button
            FloatingActionButton(systemImage: "plus") {
                onAddExpense()
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
            .accessibilityLabel("Add expense")
        }
    }
}

// MARK: - Expense Row View

/// Individual row displaying an expense
struct ExpenseRowView: View {
    @ObservedObject var viewModel: TripViewModel
    let expense: Expense
    let onEdit: () -> Void
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(expense.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let payer = trip.participants.first(where: { $0.id == expense.paidBy.id }) {
                        Text("Paid by \(payer.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                CurrencyText(
                    amount: expense.amount,
                    symbol: expense.currencySymbol,
                    color: .primary,
                    font: .headline
                )
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: onEdit) {
                Label("Edit Expense", systemImage: "pencil")
            }
            
            Button(role: .destructive, action: {
                viewModel.deleteExpense(withId: expense.id)
            }) {
                Label("Delete Expense", systemImage: "trash")
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(expense.title), \(formatCurrency(expense.amount)), paid by \(payerName)")
        .accessibilityHint("Double tap to edit expense")
    }
    
    // MARK: - Helper Properties
    
    /// Get the current trip from view model
    private var trip: Trip {
        viewModel.currentTrip ?? Trip(id: "", name: "", description: "", startDate: nil, endDate: nil, participants: [], expenses: [], inviteCode: "")
    }
    
    /// Get the payer's name for accessibility
    private var payerName: String {
        if let payer = trip.participants.first(where: { $0.id == expense.paidBy.id }) {
            return payer.name
        }
        return "Unknown"
    }
    
    /// Format currency for accessibility labels
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = expense.currencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(expense.currencySymbol)\(amount)"
    }
}

// Note: FloatingActionButton and CurrencyText components are now used from SharedComponents.swift 