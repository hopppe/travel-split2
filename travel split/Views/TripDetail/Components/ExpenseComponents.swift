//
//  ExpenseComponents.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation
import FirebaseCore

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
    @State private var isInternalUpdate: Bool = false

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

                    TextField("zero_placeholder".localized, text: $editableAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
                        .frame(width: 80)
                        .onChange(of: editableAmount) { newValue in
                            // Only process user-initiated changes
                            if !isInternalUpdate && isFocused {
                                // Convert text to double, handling Arabic numerals and various formats
                                let doubleValue = newValue.toDoubleFromLocalizedNumber()
                                onAmountChanged(doubleValue)
                            }
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
        .onChange(of: amount) { newAmount in
            // Always update when amount changes from parent (main amount field changed)
            // The isInternalUpdate flag prevents feedback loops
            updateEditableAmount(with: newAmount)
        }
    }

    /// Update the editable amount text field
    private func updateEditableAmount(with value: Double? = nil) {
        isInternalUpdate = true
        let amountToUse = value ?? amount
        let newValue: String
        if amountToUse > 0 {
            newValue = String(format: "%.\(decimalPlaces)f", amountToUse)
        } else {
            newValue = ""
        }
        print("   💵 ParticipantRow[\(user.name)] - Updating display: \(amountToUse) → '\(newValue)'")
        editableAmount = newValue
        isInternalUpdate = false
    }
}

// MARK: - Currency Picker View
/// A reusable currency picker view
struct ExpenseCurrencyPickerView: View {
    @Binding var currencySymbol: String
    @Binding var isPresented: Bool
    let options: [String]

    // Get currency data from centralized service
    private var currencyOptions: [CurrencyConverterService.CurrencyInfo] {
        CurrencyConverterService.shared.getAllCurrencies()
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(currencyOptions, id: \.code) { currency in
                    Button(action: {
                        currencySymbol = currency.symbol
                        isPresented = false
                    }) {
                        HStack(spacing: 12) {
                            // Flag emoji
                            Text(currency.flag)
                                .font(.title2)
                                .frame(width: 40)

                            // Currency symbol
                            Text(currency.symbol)
                                .font(.title3)
                                .frame(width: 50, alignment: .leading)
                                .foregroundColor(.secondary)

                            // Currency name
                            Text(currency.name)
                                .font(.headline)

                            Spacer()

                            if currency.symbol == currencySymbol {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("select_currency_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("cancel".localized) {
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