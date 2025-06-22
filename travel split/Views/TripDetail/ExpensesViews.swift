//
//  ExpensesViews.swift
//  free split
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
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Removed divider
                
                if trip.expenses.isEmpty {
                    EmptyExpensesView(onAddExpense: onAddExpense)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("No expenses")
                        .padding(.top, 6) // Slightly increased padding
                } else {
                    ExpensesContentView(
                        viewModel: viewModel,
                        trip: trip,
                        onAddExpense: onAddExpense,
                        onEditExpense: onEditExpense
                    )
                    .padding(.top, 6) // Slightly increased padding
                }
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
    
    @State private var isRefreshing = false
    
    // Group expenses by day for better organization
    private var expensesByDay: [(String, [Expense])] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .none
        
        let sortedExpenses = trip.expenses.sorted(by: { $0.date > $1.date })
        let grouped = Dictionary(grouping: sortedExpenses) { expense in
            dateFormatter.string(from: expense.date)
        }
        
        return grouped.sorted { (first, second) in
            // Sort by the first expense date in each group (most recent first)
            guard let firstDate = first.value.first?.date,
                  let secondDate = second.value.first?.date else {
                return false
            }
            return firstDate > secondDate
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                LazyVStack(spacing: 8) {
                    // Group expenses by day with date headers
                    ForEach(expensesByDay, id: \.0) { (dateString, expenses) in
                        VStack(spacing: 8) {
                            // Date header for each day
                            HStack {
                                Text(dateString)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                            
                            // Expenses for this day - joined together with no spacing
                            VStack(spacing: 0) {
                                ForEach(Array(expenses.enumerated()), id: \.element.id) { index, expense in
                                    ExpenseRowView(
                                        viewModel: viewModel,
                                        expense: expense,
                                        onEdit: {
                                            onEditExpense(expense)
                                        },
                                        showDate: false, // Don't show date on individual expenses
                                        isFirst: index == 0,
                                        isLast: index == expenses.count - 1
                                    )
                                    .padding(.horizontal)
                                    
                                    // Add divider between expenses on the same day (except for the last one)
                                    if index < expenses.count - 1 {
                                        Divider()
                                            .padding(.horizontal, 24)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 80) // Space for FAB
            }
            .refreshable {
                print("🔄 REFRESHING EXPENSES FROM PULL GESTURE")
                await refreshData()
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
    
    // Refresh function using async/await
    private func refreshData() async {
        // Set state to refreshing
        isRefreshing = true
        
        // Create a Task that can be awaited
        return await withCheckedContinuation { continuation in
            // Call the view model's refresh method
            viewModel.refreshCurrentTrip { success in
                print("🔄 EXPENSES REFRESHED - Success: \(success), Trip has \(self.trip.expenses.count) expenses")
                
                // Set state to not refreshing
                isRefreshing = false
                
                // Resume the continuation
                continuation.resume()
            }
        }
    }
}

// MARK: - Expense Row View

/// Individual row displaying an expense
struct ExpenseRowView: View {
    @ObservedObject var viewModel: TripViewModel
    let expense: Expense
    let onEdit: () -> Void
    var showDate: Bool = true
    var isFirst: Bool = false
    var isLast: Bool = false
    @State private var isShowingDeleteConfirmation = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
    
    var body: some View {
        ExpenseButton(
            expense: expense,
            trip: trip,
            dateFormatter: dateFormatter,
            onEdit: onEdit,
            showDate: showDate,
            isFirst: isFirst,
            isLast: isLast
        )
        .contextMenu {
            ExpenseContextMenu(
                onEdit: onEdit,
                onDelete: { isShowingDeleteConfirmation = true }
            )
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                isShowingDeleteConfirmation = true
            }
        }
        .confirmationDialog(
            "Delete Expense",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteExpense(withId: expense.id)
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this expense?")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Double tap to edit expense")
    }
    
    // MARK: - Helper Properties
    
    /// Get the current trip from view model
    private var trip: Trip {
        viewModel.currentTrip ?? Trip(id: "", name: "", description: "", startDate: nil, endDate: nil, participants: [], expenses: [], inviteCode: "", baseCurrencyCode: "USD")
    }
    
    /// Format currency for accessibility labels
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = expense.currencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(expense.currencySymbol)\(amount)"
    }
    
    /// Get the payer's name for accessibility
    private var payerName: String {
        if let payer = trip.participants.first(where: { $0.id == expense.paidBy.id }) {
            return payer.name
        }
        return expense.paidBy.name
    }
    
    // Simplify complex accessibility label by pre-computing it
    private var accessibilityDescription: String {
        let title = expense.title
        let amount = formatCurrency(expense.amount)
        let payer = payerName
        return "\(title), \(amount), paid by \(payer)"
    }
}

// MARK: - Subviews for ExpenseRowView

/// The main button content for an expense row
struct ExpenseButton: View {
    let expense: Expense
    let trip: Trip
    let dateFormatter: DateFormatter
    let onEdit: () -> Void
    var showDate: Bool = true
    var isFirst: Bool = false
    var isLast: Bool = false
    
    var body: some View {
        Button(action: onEdit) {
            HStack {
                // Left side - expense details
                ExpenseDetails(
                    expense: expense,
                    trip: trip, 
                    dateFormatter: dateFormatter,
                    showDate: showDate
                )
                
                Spacer()
                
                // Right side - amount
                CurrencyText(
                    amount: expense.amount,
                    symbol: expense.currencySymbol,
                    color: .primary,
                    font: .headline,
                    showBaseConversion: true,
                    expenseCurrency: expense.currencyCode ?? "USD",
                    baseCurrency: trip.baseCurrencyCode,
                    baseSymbol: trip.baseCurrencySymbol
                )
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: isFirst ? 12 : 0,
                    bottomLeadingRadius: isLast ? 12 : 0,
                    bottomTrailingRadius: isLast ? 12 : 0,
                    topTrailingRadius: isFirst ? 12 : 0
                )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// The details part of an expense (left side of row)
struct ExpenseDetails: View {
    let expense: Expense
    let trip: Trip
    let dateFormatter: DateFormatter
    var showDate: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Title
            Text(expense.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            // Payer info
            PayerText(expense: expense, trip: trip)
            
            // Date (only show if requested)
            if showDate {
                Text(dateFormatter.string(from: expense.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Text showing who paid for an expense
struct PayerText: View {
    let expense: Expense
    let trip: Trip
    
    var body: some View {
        if let payer = trip.participants.first(where: { $0.id == expense.paidBy.id }) {
            Text("Paid by \(payer.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            Text("Paid by \(expense.paidBy.name)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

/// Context menu for expense actions
struct ExpenseContextMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button {
            onEdit()
        } label: {
            Label("Edit Expense", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            onDelete()
        } label: {
            Label("Delete", systemImage: "trash.fill")
                .foregroundColor(.red)
        }
    }
}

// Note: FloatingActionButton and CurrencyText components are now used from SharedComponents.swift 