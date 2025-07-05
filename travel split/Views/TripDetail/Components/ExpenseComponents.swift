//
//  ExpenseComponents.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation
import FirebaseCore
import TravelSplitModels
import TravelSplitServices
import TravelSplitViewModels
import TravelSplitExtensions

// MARK: - Participant Row View
/// A reusable row view for participant selection and amount entry
struct ParticipantRow: View {
    let user: User
    let isSelected: Bool
    let currencySymbol: String
    let amount: Double
    let onToggle: () -> Void
    let onAmountChanged: (Double?) -> Void
    var shouldClearOnEdit: Bool = false
    var decimalPlaces: Int = 2
    
    @State private var editableAmount: String = ""
    @State private var isFocused: Bool = false
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        HStack {
            // Checkbox and name
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                    
                    Text(user.name)
                        .foregroundColor(.primary)
                        .rtlAwareAlignment()
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Only show amount field if participant is selected
            if isSelected {
                HStack(spacing: 4) {
                    Text(currencySymbol)
                        .foregroundColor(.secondary)
                        .font(.subheadline)
                    
                    TextField("0.00", text: $editableAmount)
                        .keyboardType(UIKeyboardType.decimalPad)
                        .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
                        .frame(width: 80)
                        .onReceive(editableAmount.publisher.collect()) { _ in
                            // Convert text to double and notify parent
                            let doubleValue = Double(editableAmount.replacingOccurrences(of: ",", with: "."))
                            onAmountChanged(doubleValue)
                        }
                        .onTapGesture {
                            isFocused = true
                            if shouldClearOnEdit && !editableAmount.isEmpty {
                                editableAmount = ""
                            }
                        }
                }
            }
        }
        .onAppear {
            // Initialize the text field with the current amount
            updateEditableAmount()
        }
        .onChange(of: amount) { _ in
            // Update text field when amount changes externally (unless user is editing)
            if !isFocused {
                updateEditableAmount()
            }
        }
        .onChange(of: isFocused) { focused in
            if !focused {
                // When focus is lost, ensure the display is up to date
                updateEditableAmount()
            }
        }
    }
    
    /// Update the editable amount text field
    private func updateEditableAmount() {
        if amount > 0 {
            editableAmount = String(format: "%.\(decimalPlaces)f", amount)
        } else {
            editableAmount = ""
        }
    }
}

// MARK: - Currency Picker View
/// A reusable currency picker view
struct ExpenseCurrencyPickerView: View {
    @Binding var currencySymbol: String
    @Binding var isPresented: Bool
    let options: [String]
    
    // Currency option with symbol and code
    private struct CurrencyOption: Identifiable {
        let symbol: String
        let code: String
        let name: String
        var id: String { symbol }
        
        var displayText: String {
            "\(symbol) - \(code)"
        }
    }
    
    // Map currency symbols to codes and names
    private var currencyOptions: [CurrencyOption] {
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
            "﷼": "SAR"
        ]
        
        let currencyNames = [
            "USD": "US Dollar",
            "EUR": "Euro",
            "GBP": "British Pound",
            "JPY": "Japanese Yen",
            "INR": "Indian Rupee",
            "RUB": "Russian Ruble",
            "KRW": "Korean Won",
            "AUD": "Australian Dollar",
            "CAD": "Canadian Dollar",
            "HKD": "Hong Kong Dollar",
            "PHP": "Philippine Peso",
            "TRY": "Turkish Lira",
            "UAH": "Ukrainian Hryvnia",
            "NGN": "Nigerian Naira",
            "ZAR": "South African Rand",
            "SAR": "Saudi Riyal"
        ]
        
        return options.compactMap { symbol in
            guard let code = currencyCodes[symbol] else { return nil }
            let name = currencyNames[code] ?? code
            return CurrencyOption(symbol: symbol, code: code, name: name)
        }.sorted { $0.code < $1.code }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(currencyOptions) { option in
                    Button(action: {
                        currencySymbol = option.symbol
                        isPresented = false
                    }) {
                        HStack {
                            Text(option.symbol)
                                .font(.title2)
                                .frame(width: 50, alignment: .leading)
                            
                            Text(option.name)
                                .font(.headline)
                            
                            Spacer()
                            
                            if option.symbol == currencySymbol {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        #if !SKIP
                        .contentShape(Rectangle())
                        #endif
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview
struct ExpenseComponents_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Preview ParticipantRow
            ParticipantRow(
                user: User.create(name: "John Doe", email: "john@example.com"),
                isSelected: true,
                currencySymbol: "$",
                amount: 25.50,
                onToggle: {},
                onAmountChanged: { _ in }
            )
            .previewLayout(.sizeThatFits)
            .padding()
            
            // Preview with no selection
            ParticipantRow(
                user: User.create(name: "Jane Smith", email: "jane@example.com"),
                isSelected: false,
                currencySymbol: "$",
                amount: 0,
                onToggle: {},
                onAmountChanged: { _ in }
            )
            .previewLayout(.sizeThatFits)
            .padding()
        }
        .previewDisplayName("Participant Rows")
    }
} 