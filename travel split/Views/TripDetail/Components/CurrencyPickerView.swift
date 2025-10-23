//
//  CurrencyPickerView.swift
//  EquiSplit
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
            .navigationTitle("select_currency_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
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

    // Get currency data from centralized service
    private var currencyOptions: [CurrencyConverterService.CurrencyInfo] {
        CurrencyConverterService.shared.getAllCurrencies()
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(currencyOptions, id: \.code) { currency in
                    Button(action: {
                        currencyCode = currency.code
                        isPresented = false
                        onCurrencySelected?(currency.code)
                    }) {
                        HStack(spacing: 12) {
                            // Flag emoji
                            Text(currency.flag)
                                .font(.title2)
                                .frame(width: 40)

                            // Currency name (full name, not abbreviation)
                            Text(currency.name)
                                .font(.headline)

                            Spacer()

                            // Currency code (abbreviation)
                            Text(currency.code)
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            if currency.code == currencyCode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("select_currency_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
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