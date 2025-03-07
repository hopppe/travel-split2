//
//  AddExpenseSheet.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation

// MARK: - Add Expense Sheet
struct AddExpenseSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var expenseName = ""
    @State private var expenseAmount = ""
    @State private var selectedPayer: User?
    @State private var selectedParticipants: Set<User> = []
    @State private var participantAmounts: [String: Double] = [:]
    @State private var currencySymbol = "$"
    @State private var showCurrencyPicker = false
    
    // Currency options
    private let currencyOptions = ["$", "€", "£", "¥", "₹", "₽", "₩", "A$", "C$", "HK$", "₱", "₺", "₴", "₦", "R"]
    
    var body: some View {
        Form {
            // MARK: - Expense Details Section
            Section(header: Text("Expense Info")) {
                // Description field
                TextField("Description", text: $expenseName)
                    .accessibilityLabel("Expense description")
                
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
                    .accessibilityLabel("Select currency")
                    
                    TextField("Amount", text: $expenseAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Expense amount")
                }
            }
            
            // MARK: - Payer Section
            if let trip = viewModel.currentTrip {
                Section {
                    HStack {
                        Text("Paid By")
                            .font(.body)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Picker("", selection: $selectedPayer) {
                            ForEach(trip.participants) { user in
                                Text(user.name).tag(user as User?)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Select who paid for this expense")
                }
                
                // MARK: - Participants Section
                Section(header: Text("Split Between")) {
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
        .navigationTitle("Add Expense")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveExpense()
                }
                .disabled(!isFormValid())
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            CurrencyPickerView(
                currencySymbol: $currencySymbol,
                isPresented: $showCurrencyPicker,
                options: currencyOptions
            )
        }
        .onAppear {
            // Initialize default values when view appears
            initializeDefaults()
        }
        .onChange(of: expenseAmount) { oldValue, newValue in
            updateSplitAmounts()
        }
        .onChange(of: selectedParticipants.count) { oldValue, newValue in
            updateSplitAmounts()
        }
    }
    
    // MARK: - Helper Methods
    
    /// Initialize default values for new expense
    private func initializeDefaults() {
        // Default to current user as payer
        selectedPayer = viewModel.currentUser
        
        // Default select all participants
        if let trip = viewModel.currentTrip {
            selectedParticipants = Set(trip.participants)
            updateSplitAmounts()
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
        
        // Add the expense
        viewModel.addExpenseToCurrentTrip(
            title: expenseName,
            amount: amount,
            paidBy: payer,
            splitType: .custom, // Always use custom split
            customShares: shares,
            category: .other,
            currencyCode: getCurrencyCode(for: currencySymbol)
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
            "R": "ZAR"
        ]
        
        return currencyCodes[symbol] ?? "USD"
    }
}

// MARK: - Preview Provider
struct AddExpenseSheet_Previews: PreviewProvider {
    static var previews: some View {
        let previewUser = User.create(name: "Preview User", email: "preview@example.com")
        let viewModel = TripViewModel(currentUser: previewUser)
        return AddExpenseSheet(viewModel: viewModel)
    }
} 