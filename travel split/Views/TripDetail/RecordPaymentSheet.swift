//
//  RecordPaymentSheet.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation

// MARK: - Record Payment Sheet
struct RecordPaymentSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var paymentAmount = ""
    @State private var selectedPayer: User?
    @State private var selectedRecipient: User?
    @State private var currencySymbol = "$"
    @State private var showCurrencyPicker = false
    @State private var note = ""
    @State private var isSettlingAllDebts = false
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager

    // Get currency options from centralized service
    private var currencyOptions: [String] {
        CurrencyConverterService.shared.getAllCurrencySymbols()
    }

    var body: some View {
        Form {
            // Payment Details Section
            Section(header: Text("payment_details".localized)) {
                // Amount field with currency selector
                HStack {
                    Button(action: {
                        showCurrencyPicker = true
                    }) {
                        Text(currencySymbol)
                            .font(.headline)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel("select_currency".localized)
                    
                    TextField("amount".localized, text: $paymentAmount)
                        .keyboardType(.decimalPad)
                        .safeRTLTextField()
                        .accessibilityLabel("payment_amount".localized)
                }
                
                // Payer selector (who made the payment)
                Picker("from".localized, selection: $selectedPayer) {
                    if let currentUser = viewModel.findCurrentUserInTrip() {
                        HStack {
                            ParticipantAvatar(participant: currentUser, size: 20)
                            Text(currentUser.name)
                        }
                        .tag(Optional(currentUser))
                    }
                    ForEach(viewModel.currentTrip?.participants ?? []) { participant in
                        if participant.id != viewModel.findCurrentUserInTrip()?.id {
                            HStack {
                                ParticipantAvatar(participant: participant, size: 20)
                                Text(participant.name)
                            }
                            .tag(Optional(participant))
                        }
                    }
                }
                .pickerStyle(.menu)
                
                // Recipient selector (who received the payment)
                Picker("to".localized, selection: $selectedRecipient) {
                    Text("select_recipient".localized).tag(nil as User?)
                    ForEach(viewModel.currentTrip?.participants ?? []) { participant in
                        if participant.id != selectedPayer?.id {
                            HStack {
                                ParticipantAvatar(participant: participant, size: 20)
                                Text(participant.name)
                            }
                            .tag(Optional(participant))
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(selectedPayer == nil)
                
                // Optional note field
                TextField("note_optional".localized, text: $note)
                    .safeRTLTextField()
                    .accessibilityLabel("payment_note".localized)
            }
            
            // Info section
            Section(footer: Text("record_payment_info".localized).rtlAwareAlignment()) {
                EmptyView()
            }
            
            // Action buttons section
            Section {
                VStack(spacing: 12) {
                    // Record Payment button
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        recordPayment()
                    }) {
                        Text("record_payment".localized)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!isFormValid)
                    
                    // Settle All Balances button
                    Button(action: {
                        HapticManager.shared.lightImpact()
                        settleAllBalances()
                    }) {
                        Text("settle_all_my_balances".localized)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(userHasNoBalances())
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets())
        }
        .navigationTitle("record_payment_title".localized)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("cancel".localized) {
                    HapticManager.shared.lightImpact()
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            VStack {
                Text("select_currency_title".localized)
                    .font(.headline)
                    .padding()
                
                List(currencyOptions, id: \.self) { symbol in
                    Button(action: {
                        self.currencySymbol = symbol
                        self.showCurrencyPicker = false
                    }) {
                        HStack {
                            Text(symbol)
                                .font(.headline)
                            Spacer()
                            if self.currencySymbol == symbol {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
                
                Button("cancel".localized) {
                    self.showCurrencyPicker = false
                }
                .padding()
            }
        }
        .onAppear {
            initializeDefaults()
        }
        .disabled(isSettlingAllDebts)
        .overlay(
            Group {
                if isSettlingAllDebts {
                    LoadingOverlay(message: "recording_payments")
                }
            }
        )
    }
    
    // MARK: - Helper Methods
    
    /// Initialize default values
    private func initializeDefaults() {
        // Default payer to current user
        if let userInTrip = viewModel.findCurrentUserInTrip() {
            selectedPayer = userInTrip
        }
        
        // Default currency to trip's base currency
        if let trip = viewModel.currentTrip {
            currencySymbol = trip.baseCurrencySymbol
        }
    }
    
    /// Check if the form is valid for submission
    private var isFormValid: Bool {
        guard let amount = getAmount(),
              amount > 0,
              selectedPayer != nil,
              selectedRecipient != nil,
              selectedPayer?.id != selectedRecipient?.id else {
            return false
        }
        
        return true
    }
    
    /// Get numeric amount from string input
    /// Handles Arabic-Indic numerals, various decimal separators, and localized number formats
    private func getAmount() -> Double? {
        return paymentAmount.toDoubleFromLocalizedNumber()
    }
    
    /// Get currency code from symbol
    private func getCurrencyCode() -> String {
        let symbolToCode = [
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
        
        return symbolToCode[currencySymbol] ?? "USD"
    }
    
    /// Record the payment
    private func recordPayment() {
        guard let payer = selectedPayer,
              let recipient = selectedRecipient,
              let amount = getAmount() else {
            return
        }
        
        // Create a payment title using localized string
        let paymentTitle = note.isEmpty ? 
            String(format: "payment_from_to".localized, payer.name, recipient.name) : 
            note
        
        // Create a payment expense (special expense that only involves two people)
        viewModel.addPaymentToCurrentTrip(
            title: paymentTitle,
            amount: amount,
            paidBy: payer,
            paidTo: recipient,
            currencyCode: getCurrencyCode()
        )
        
        dismiss()
    }
    
    /// Check if the current user has any debts to settle
    private func userHasNoBalances() -> Bool {
        guard let _ = viewModel.currentTrip,
              let currentUser = viewModel.findCurrentUserInTrip() else {
            return true
        }
        
        let debts = viewModel.calculateDebts()
        // Check if the user is involved in any debts (either owing or being owed)
        return !debts.contains { $0.from.id == currentUser.id || $0.to.id == currentUser.id }
    }
    
    /// Automatically settle all balances the current user has (both debts owed and money owed to them)
    private func settleAllBalances() {
        guard let trip = viewModel.currentTrip,
              let currentUser = viewModel.findCurrentUserInTrip() else {
            return
        }
        
        let debts = viewModel.calculateDebts()
        
        // Filter debts where the current user is involved (either owing or being owed)
        let myBalances = debts.filter { $0.from.id == currentUser.id || $0.to.id == currentUser.id }
        
        if myBalances.isEmpty {
            return
        }
        
        isSettlingAllDebts = true
        
        // Process each balance and record a payment
        for debt in myBalances {
            // Determine if the user is the payer or recipient
            if debt.from.id == currentUser.id {
                // User owes money to someone else - use localized payment title
                let paymentTitle = String(format: "payment_from_to".localized, currentUser.name, debt.to.name)
                
                viewModel.addPaymentToCurrentTrip(
                    title: paymentTitle,
                    amount: debt.amount,
                    paidBy: currentUser,
                    paidTo: debt.to,
                    currencyCode: trip.baseCurrencyCode
                )
            } else {
                // Someone owes money to the user - use localized payment title
                let paymentTitle = String(format: "payment_from_to".localized, debt.from.name, currentUser.name)
                
                viewModel.addPaymentToCurrentTrip(
                    title: paymentTitle,
                    amount: debt.amount,
                    paidBy: debt.from,
                    paidTo: currentUser,
                    currencyCode: trip.baseCurrencyCode
                )
            }
        }
        
        // Introduce a small delay to allow Firebase to process the updates
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isSettlingAllDebts = false
            dismiss()
        }
    }
} 
