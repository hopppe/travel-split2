//
//  RecordPaymentSheet.swift
//  travel split
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
    
    // Currency options - same as in other expense sheets
    private let currencyOptions = ["$", "€", "£", "¥", "₹", "₽", "₩", "A$", "C$", "HK$", "₱", "₺", "₴", "₦", "R", "﷼"]
    
    var body: some View {
        Form {
            // Payment Details Section
            Section(header: Text("Payment Details")) {
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
                    .accessibilityLabel("Select currency")
                    
                    TextField("Amount", text: $paymentAmount)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Payment amount")
                }
                
                // Payer selector (who made the payment)
                Picker("From", selection: $selectedPayer) {
                    if let currentUser = viewModel.findCurrentUserInTrip() {
                        Text(currentUser.name).tag(Optional(currentUser))
                    }
                    ForEach(viewModel.currentTrip?.participants ?? []) { participant in
                        if participant.id != viewModel.findCurrentUserInTrip()?.id {
                            Text(participant.name).tag(Optional(participant))
                        }
                    }
                }
                .pickerStyle(.menu)
                
                // Recipient selector (who received the payment)
                Picker("To", selection: $selectedRecipient) {
                    Text("Select recipient").tag(nil as User?)
                    ForEach(viewModel.currentTrip?.participants ?? []) { participant in
                        if participant.id != selectedPayer?.id {
                            Text(participant.name).tag(Optional(participant))
                        }
                    }
                }
                .pickerStyle(.menu)
                .disabled(selectedPayer == nil)
                
                // Optional note field
                TextField("Note (optional)", text: $note)
                    .accessibilityLabel("Payment note")
            }
            
            // Info section
            Section(footer: Text("Recording a payment helps keep track of who has settled their debts. This creates a special expense that shows the debt has been paid.")) {
                EmptyView()
            }
            
            // Record button
            Section {
                Button(action: recordPayment) {
                    Text("Record Payment")
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .disabled(!isFormValid)
            }
        }
        .navigationTitle("Record Payment")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showCurrencyPicker) {
            VStack {
                Text("Select Currency")
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
                
                Button("Cancel") {
                    self.showCurrencyPicker = false
                }
                .padding()
            }
        }
        .onAppear {
            initializeDefaults()
        }
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
    private func getAmount() -> Double? {
        return Double(paymentAmount.replacingOccurrences(of: ",", with: "."))
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
            "﷼": "SAR"
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
        
        // Create a payment title
        let paymentTitle = note.isEmpty ? 
            "Payment from \(payer.name) to \(recipient.name)" : 
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
} 