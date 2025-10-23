//
//  SmartCurrencyPicker.swift
//  EquiSplit
//
//  Enhanced currency picker with search and recent selections
//

import SwiftUI

struct SmartCurrencyPicker: View {
    @Binding var selectedCurrencyCode: String
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @EnvironmentObject var languageManager: LanguageManager

    private let currencyManager = CurrencyPreferencesManager.shared

    var body: some View {
        NavigationStack {
            List {
                // Recent currencies section
                if !recentCurrencies.isEmpty && searchText.isEmpty {
                    Section(header: Text("recent_currencies".localized)) {
                        ForEach(recentCurrencies, id: \.code) { currency in
                            CurrencyRow(currency: currency, isSelected: selectedCurrencyCode == currency.code) {
                                selectCurrency(currency.code)
                            }
                        }
                    }
                }

                // All currencies section
                Section(header: Text(searchText.isEmpty ? "all_currencies".localized : "search_results".localized)) {
                    ForEach(filteredCurrencies, id: \.code) { currency in
                        CurrencyRow(currency: currency, isSelected: selectedCurrencyCode == currency.code) {
                            selectCurrency(currency.code)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "search_currencies".localized)
            .navigationTitle("select_currency_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
        .forceRTL()
    }

    private var recentCurrencies: [(symbol: String, code: String, name: String)] {
        let recentCodes = currencyManager.getRecentCurrencies()
        let allCurrencies = currencyManager.getAllCurrencies()
        return recentCodes.compactMap { code in
            allCurrencies.first { $0.code == code }
        }
    }

    private var filteredCurrencies: [(symbol: String, code: String, name: String)] {
        let allCurrencies = currencyManager.getAllCurrencies()

        if searchText.isEmpty {
            return allCurrencies
        }

        return allCurrencies.filter {
            $0.code.lowercased().contains(searchText.lowercased()) ||
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.symbol.contains(searchText)
        }
    }

    private func selectCurrency(_ code: String) {
        selectedCurrencyCode = code
        currencyManager.addRecentCurrency(code)
        HapticManager.shared.selectionChanged()
        dismiss()
    }
}

/// Row view for a single currency
struct CurrencyRow: View {
    let currency: (symbol: String, code: String, name: String)
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                // Currency symbol
                Text(currency.symbol)
                    .font(.title3)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(currency.name)
                        .font(.body)
                        .foregroundColor(.primary)

                    Text(currency.code)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.headline)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}
