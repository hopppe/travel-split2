//
//  CurrencyConverterService.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import Foundation

// MARK: - Currency Converter Service

/// Service for handling currency conversions
/// In a real app, we would fetch real-time rates from an API,
/// but for simplicity we're using static exchange rates here
class CurrencyConverterService {
    
    // Singleton instance
    static let shared = CurrencyConverterService()
    
    // Private constructor for singleton
    private init() {}
    
    // Static exchange rates (based on USD as reference)
    // In a real app, these would be dynamic and updated from an API
    private let exchangeRates: [String: Double] = [
        "USD": 1.0,      // US Dollar (reference)
        "EUR": 0.85,     // Euro
        "GBP": 0.73,     // British Pound
        "JPY": 110.0,    // Japanese Yen
        "CAD": 1.25,     // Canadian Dollar
        "AUD": 1.35,     // Australian Dollar
        "INR": 74.0,     // Indian Rupee
        "RUB": 73.0,     // Russian Ruble
        "KRW": 1150.0,   // South Korean Won
        "HKD": 7.8,      // Hong Kong Dollar
        "PHP": 50.0,     // Philippine Peso
        "TRY": 8.5,      // Turkish Lira
        "UAH": 27.0,     // Ukrainian Hryvnia
        "NGN": 410.0,    // Nigerian Naira
        "ZAR": 14.5      // South African Rand
    ]
    
    // Convert amount from one currency to another
    func convert(amount: Double, from fromCurrency: String, to toCurrency: String) -> Double {
        guard let fromRate = exchangeRates[fromCurrency],
              let toRate = exchangeRates[toCurrency] else {
            return amount // Fall back to original amount if currency not found
        }
        
        // Convert to USD first (as reference), then to target currency
        let amountInUSD = amount / fromRate
        return amountInUSD * toRate
    }
    
    // Get all available currency codes
    func getAllCurrencyCodes() -> [String] {
        return Array(exchangeRates.keys).sorted()
    }
    
    // Get all available currency symbols with codes
    func getAllCurrencySymbolsWithCodes() -> [(symbol: String, code: String)] {
        let symbols = [
            "USD": "$",
            "EUR": "€",
            "GBP": "£",
            "JPY": "¥",
            "CAD": "C$",
            "AUD": "A$",
            "INR": "₹",
            "RUB": "₽",
            "KRW": "₩",
            "HKD": "HK$",
            "PHP": "₱",
            "TRY": "₺",
            "UAH": "₴",
            "NGN": "₦",
            "ZAR": "R"
        ]
        
        return exchangeRates.keys.sorted().map { code in
            (symbol: symbols[code] ?? code, code: code)
        }
    }
} 