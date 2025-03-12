//
//  ExpenseComponents.swift
//  travel split
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
    
    var body: some View {
        HStack {
            // Checkbox and name
            Button(action: onToggle) {
                HStack {
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected ? .accentColor : .gray)
                    
                    Text(user.name)
                        .foregroundColor(.primary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            Spacer()
            
            // Only show amount field if participant is selected
            if isSelected {
                HStack {
                    Text(currencySymbol)
                        .foregroundColor(.secondary)
                    
                    // Modified TextField implementation for better UX
                    TextField("0", text: Binding(
                        get: { 
                            if isFocused {
                                // When focused, show empty field for easy entry
                                return ""
                            } else {
                                return amount == 0 ? "0" : String(format: "%.\(decimalPlaces)f", amount)
                            }
                        },
                        set: { newValue in
                            if let value = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                                onAmountChanged(value)
                            } else if newValue.isEmpty {
                                onAmountChanged(0)
                            }
                        }
                    ))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 70)
                    .onTapGesture {
                        // Set focus state and clear the field
                        isFocused = true
                        
                        // Reset amount to zero when tapped
                        if shouldClearOnEdit {
                            onAmountChanged(0)
                        }
                    }
                    .onSubmit {
                        isFocused = false
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .accessibilityLabel("\(user.name) - \(isSelected ? "selected" : "not selected")")
        .accessibilityHint("Double tap to \(isSelected ? "remove from" : "add to") expense")
        .onAppear {
            isFocused = false
        }
    }
}

// MARK: - Currency Picker View
/// A reusable currency picker view
struct ExpenseCurrencyPickerView: View {
    @Binding var currencySymbol: String
    @Binding var isPresented: Bool
    let options: [String]
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.self) { currency in
                    Button(action: {
                        currencySymbol = currency
                        isPresented = false
                    }) {
                        HStack {
                            Text(currency)
                                .font(.title2)
                            
                            Spacer()
                            
                            if currency == currencySymbol {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .contentShape(Rectangle())
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