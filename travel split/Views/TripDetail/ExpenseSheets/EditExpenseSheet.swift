//
//  EditExpenseSheet.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation

// No need to declare our own version - we'll use the one from the models
// This avoids the "invalid redeclaration" error

// MARK: - Edit Expense Sheet
struct EditExpenseSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    
    let expense: Expense
    
    @State private var expenseName: String
    @State private var expenseAmount: String
    @State private var selectedPayer: User?
    @State private var selectedParticipants: Set<User> = []
    @State private var participantAmounts: [String: Double] = [:]
    @State private var currencySymbol: String
    @State private var showCurrencyPicker = false
    @State private var isInitialLoad = true
    @State private var expenseDate: Date
    @State private var showDatePicker = false
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager
    
    // Currency options
    private let currencyOptions = ["$", "€", "£", "¥", "₹", "₽", "₩", "A$", "C$", "HK$", "₱", "₺", "₴", "₦", "R", "﷼", "JD", "د.إ"]
    
    // Initialize with expense data
    init(viewModel: TripViewModel, expense: Expense) {
        self.viewModel = viewModel
        self.expense = expense
        
        // Initialize state properties with expense data
        _expenseName = State(initialValue: expense.title)
        _expenseAmount = State(initialValue: String(format: "%.2f", expense.amount))
        _currencySymbol = State(initialValue: expense.currencySymbol)
        _expenseDate = State(initialValue: expense.date)
    }
    
    var body: some View {
        Form {
            // MARK: - Expense Details Section
            Section(header: Text("expense_info".localized)) {
                // Description field
                TextField("description".localized, text: $expenseName)
                    .safeRTLTextField()
                    .accessibilityLabel("expense_description".localized)
                
                // Amount with currency selector
                HStack {
                    Button(action: { showCurrencyPicker = true }) {
                        Text(currencySymbol)
                            .foregroundColor(.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.systemGray5))
                            .cornerRadius(8)
                    }
                    .accessibilityLabel("select_currency".localized)
                    
                    TextField("amount".localized, text: $expenseAmount)
                        .keyboardType(.decimalPad)
                        .safeRTLTextField()
                        .accessibilityLabel("expense_amount".localized)
                }
                .rtlHStack()
            }
            
            // MARK: - Payer Section
            if let trip = viewModel.currentTrip {
                Section {
                    // Paid By row
                    HStack {
                        Text("paid_by".localized)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
                        
                        Spacer()
                        
                        Picker("", selection: $selectedPayer) {
                            ForEach(trip.participants) { user in
                                Text(user.name).tag(user as User?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                    }
                    .rtlHStack()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("select_who_paid".localized)
                    
                    // Date row
                    HStack {
                        Text("on".localized)
                            .font(.body)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
                        
                        Spacer()
                        
                        Button(action: { showDatePicker = true }) {
                            Text(formattedDate)
                                .foregroundColor(.primary)
                        }
                    }
                    .rtlHStack()
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("select_expense_date".localized)
                }
                
                // MARK: - Participants Section
                Section(header: Text("split_between".localized)) {
                    ForEach(trip.participants) { user in
                        ParticipantRow(
                            user: user,
                            isSelected: selectedParticipants.contains(user),
                            currencySymbol: currencySymbol,
                            amount: participantAmounts[user.id] ?? 0,
                            onToggle: {
                                if selectedParticipants.contains(user) {
                                    // Remove participant
                                    selectedParticipants.remove(user)
                                    participantAmounts.removeValue(forKey: user.id)
                                    // Recalculate split for remaining participants
                                    if let amount = getAmount(), amount > 0, !selectedParticipants.isEmpty {
                                        let equalAmount = amount / Double(selectedParticipants.count)
                                        for participant in selectedParticipants {
                                            participantAmounts[participant.id] = equalAmount
                                        }
                                    }
                                } else {
                                    // Add participant with equal share
                                    selectedParticipants.insert(user)
                                    if let amount = getAmount(), amount > 0 {
                                        let equalAmount = amount / Double(selectedParticipants.count)
                                        for participant in selectedParticipants {
                                            participantAmounts[participant.id] = equalAmount
                                        }
                                    }
                                }
                            },
                            onAmountChanged: { newAmount in
                                let amount = newAmount ?? 0
                                participantAmounts[user.id] = amount
                                updateOtherAmounts(changedUserId: user.id)
                            },
                            shouldClearOnEdit: true,
                            decimalPlaces: 2
                        )
                    }
                }
            }
        }
        .forceRTL()
        .navigationTitle("edit_expense_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button("cancel".localized) {
                dismiss()
            },
            trailing: Button("save".localized) {
                saveExpense()
            }
            .disabled(!isFormValid())
        )
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                viewModel.deleteExpense(withId: expense.id)
                dismiss()
            } label: {
                Label("delete_expense".localized, systemImage: "trash")
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .padding()
        }
        .sheet(isPresented: $showCurrencyPicker) {
            ExpenseCurrencyPickerView(
                currencySymbol: $currencySymbol,
                isPresented: $showCurrencyPicker,
                options: currencyOptions
            )
            .environmentObject(languageManager)
        }
        .sheet(isPresented: $showDatePicker) {
            NavigationStack {
                DatePicker("expense_date".localized, selection: $expenseDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .environment(\.locale, languageManager.currentLocale)
                    .padding()
                    .navigationTitle("select_date".localized)
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarItems(
                        trailing: Button("done".localized) {
                            showDatePicker = false
                        }
                    )
            }
            .presentationDetents([.medium])
            .forceRTL()
        }
        .onAppear {
            // Load expense data when view appears
            loadExpenseData()
        }
        .onChange(of: expenseAmount) { _ in
            // When amount changes, update participant splits if not in initial load
            if !isInitialLoad {
                updateSplitAmounts()
            }
        }
        .onChange(of: selectedParticipants.count) { _ in
            // When participants change, update splits
            if !isInitialLoad {
                updateSplitAmounts()
            }
        }
    }
    
    // Helper computed property for formatted date
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = languageManager.currentLocale
        formatter.dateStyle = .medium
        return formatter.string(from: expenseDate)
    }
    
    // MARK: - Helper Methods
    
    /// Load expense data into the view's state
    private func loadExpenseData() {
        if let trip = viewModel.currentTrip {
            // Set payer
            selectedPayer = trip.participants.first(where: { $0.id == expense.paidBy.id })
            
            // Set participants and their amounts from expense shares
            for share in expense.shares {
                // Find the participant in the trip
                if let participant = trip.participants.first(where: { $0.id == share.user.id }) {
                    selectedParticipants.insert(participant)
                    participantAmounts[participant.id] = share.amount
                }
            }
            
            // Mark initial load as complete
            DispatchQueue.main.async {
                isInitialLoad = false
            }
        }
    }
    
    /// Check if the form is valid for submission
    private func isFormValid() -> Bool {
        guard !expenseName.isEmpty,
              let amount = getAmount(),
              amount > 0,
              selectedPayer != nil,
              !selectedParticipants.isEmpty else {
            return false
        }
        
        return true
    }
    
    /// Save the expense with current values
    private func saveExpense() {
        guard let amount = getAmount(),
              let payer = selectedPayer else {
            return
        }
        
        // Create shares for the expense
        var shares: [ExpenseShare] = []
        
        // We're always treating this as a custom split now
        for participant in selectedParticipants {
            let participantAmount = participantAmounts[participant.id] ?? 0
            let percentage = (participantAmount / amount) * 100.0
            
            shares.append(ExpenseShare(
                user: participant,
                amount: participantAmount,
                percentage: percentage
            ))
        }
        
        // Update the expense
        viewModel.updateExpense(
            id: expense.id,
            title: expenseName,
            amount: amount,
            paidBy: payer,
            splitType: .custom, // Always use custom split
            customShares: shares,
            category: expense.category,
            currencyCode: getCurrencyCode(for: currencySymbol),
            date: expenseDate
        )
        
        dismiss()
    }
    
    /// Convert the expense amount string to a Double
    private func getAmount() -> Double? {
        return Double(expenseAmount.replacingOccurrences(of: ",", with: "."))
    }
    
    /// Update split amounts when total amount or participants change
    private func updateSplitAmounts() {
        guard let amount = getAmount(), amount > 0, !selectedParticipants.isEmpty else {
            return
        }
        
        // Calculate total of all current amounts
        let currentTotal = selectedParticipants.reduce(0.0) { total, participant in
            total + (participantAmounts[participant.id] ?? 0)
        }
        
        // Only initialize with equal amounts if no amounts exist yet or total is zero
        if currentTotal == 0 {
            let equalAmount = amount / Double(selectedParticipants.count)
            for participant in selectedParticipants {
                participantAmounts[participant.id] = equalAmount
            }
        } else if abs(currentTotal - amount) > 0.01 {
            // If there's a mismatch between total and amount, adjust proportionally
            let adjustmentFactor = amount / currentTotal
            for participant in selectedParticipants {
                if let currentAmount = participantAmounts[participant.id], currentAmount > 0 {
                    participantAmounts[participant.id] = currentAmount * adjustmentFactor
                } else {
                    // Initialize any unset amounts to equal share
                    let equalShare = amount / Double(selectedParticipants.count)
                    participantAmounts[participant.id] = equalShare
                }
            }
        }
    }
    
    /// Update other participant amounts when one amount is changed
    private func updateOtherAmounts(changedUserId: String) {
        guard let totalAmount = getAmount(), totalAmount > 0, selectedParticipants.count > 1 else {
            return
        }
        
        // Calculate current total to check if adjustment needed
        let changedAmount = participantAmounts[changedUserId] ?? 0
        let otherParticipants = selectedParticipants.filter { $0.id != changedUserId }
        let currentTotal = changedAmount + otherParticipants.reduce(0.0) { total, participant in
            total + (participantAmounts[participant.id] ?? 0)
        }
        
        // Only adjust if there's a meaningful difference
        if abs(currentTotal - totalAmount) > 0.01 {
            // If there's only one other participant, just adjust their amount
            if otherParticipants.count == 1 {
                let otherParticipant = otherParticipants.first!
                let newAmount = max(0, totalAmount - changedAmount) // Prevent negative amounts
                participantAmounts[otherParticipant.id] = newAmount
            } else {
                // Otherwise, distribute remaining amount proportionally among others
                let remainingAmount = max(0, totalAmount - changedAmount) // Prevent negative remaining
                
                // Get current total of other participants
                let otherTotal = otherParticipants.reduce(0.0) { total, participant in
                    total + (participantAmounts[participant.id] ?? 0)
                }
                
                if otherTotal > 0 {
                    // Distribute proportionally
                    let adjustmentFactor = remainingAmount / otherTotal
                    for participant in otherParticipants {
                        if let currentAmount = participantAmounts[participant.id] {
                            participantAmounts[participant.id] = currentAmount * adjustmentFactor
                        }
                    }
                } else {
                    // If otherTotal is 0, distribute equally
                    let equalShare = remainingAmount / Double(otherParticipants.count)
                    for participant in otherParticipants {
                        participantAmounts[participant.id] = equalShare
                    }
                }
            }
        }
    }
    
    /// Convert currency symbol to currency code
    private func getCurrencyCode(for symbol: String) -> String {
        let currencyCodes = [
            "$": "USD",
            "€": "EUR",
            "£": "GBP",
            "¥": "JPY",
            "₹": "INR",
            "₽": "RUB",
            "₩": "KRW",
            "A$": "AUD",
            "C$": "CAD",
            "HK$": "HKD",
            "₱": "PHP",
            "₺": "TRY",
            "₴": "UAH",
            "₦": "NGN",
            "R": "ZAR",
            "﷼": "SAR",
            "JD": "JOD",
            "د.إ": "AED"
        ]
        
        return currencyCodes[symbol] ?? "USD"
    }
}

// MARK: - Preview Provider
struct EditExpenseSheet_Previews: PreviewProvider {
    static var previews: some View {
        let previewUser = User.create(name: "Preview User", email: "preview@example.com")
        let viewModel = TripViewModel(currentUser: previewUser)
        
        // Create a sample trip with the preview user
        if viewModel.trips.isEmpty {
            viewModel.createNewTrip(name: "Preview Trip", description: "For testing")
        }
        
        // Create a temporary expense for preview
        let categoryType = ExpenseCategory.food
        let previewExpense = Expense.createEqual(
            title: "Dinner",
            amount: 100.0,
            paidBy: previewUser,
            participants: [previewUser],
            category: categoryType,
            currencyCode: "USD"
        )
        
        return EditExpenseSheet(viewModel: viewModel, expense: previewExpense)
    }
} 