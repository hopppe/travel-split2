//
//  CurrencyPickerView.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

/// A reusable currency picker view
struct CurrencyPickerView: View {
    @Binding var currencySymbol: String
    @Binding var isPresented: Bool
    var options: [String]
    var onCurrencySelected: ((String) -> Void)? = nil
    
    var body: some View {
        NavigationView {
            List {
                ForEach(options, id: \.self) { symbol in
                    Button(action: {
                        currencySymbol = symbol
                        isPresented = false
                        onCurrencySelected?(symbol)
                    }) {
                        HStack {
                            Text(symbol)
                                .font(.title2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            if symbol == currencySymbol {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

/// A currency picker that includes currency codes
struct CurrencyCodePickerView: View {
    @Binding var currencyCode: String
    @Binding var isPresented: Bool
    var onCurrencySelected: ((String) -> Void)? = nil
    
    // Get currency data from service
    private let currencyOptions = CurrencyConverterService.shared.getAllCurrencySymbolsWithCodes()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(currencyOptions, id: \.code) { currency in
                    Button(action: {
                        currencyCode = currency.code
                        isPresented = false
                        onCurrencySelected?(currency.code)
                    }) {
                        HStack {
                            Text(currency.symbol)
                                .font(.title2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color(UIColor.systemGray5))
                                .cornerRadius(8)
                            
                            Text(currency.code)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            if currency.code == currencyCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Select Currency")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct CurrencyPickerView_Previews: PreviewProvider {
    static var previews: some View {
        CurrencyPickerView(
            currencySymbol: .constant("$"),
            isPresented: .constant(true),
            options: ["$", "€", "£", "¥"]
        )
    }
} 