//
//  CurrencyPreferencesManager.swift
//  EquiSplit
//
//  Manages currency preferences and recent selections
//

import Foundation

class CurrencyPreferencesManager {
    static let shared = CurrencyPreferencesManager()

    private let recentCurrenciesKey = "recentCurrencies"
    private let maxRecentCurrencies = 3

    private init() {}

    /// Get recently used currencies
    func getRecentCurrencies() -> [String] {
        return UserDefaults.standard.stringArray(forKey: recentCurrenciesKey) ?? []
    }

    /// Add a currency to recent list
    func addRecentCurrency(_ currencyCode: String) {
        var recent = getRecentCurrencies()

        // Remove if already exists
        recent.removeAll { $0 == currencyCode }

        // Add to front
        recent.insert(currencyCode, at: 0)

        // Limit to max
        if recent.count > maxRecentCurrencies {
            recent = Array(recent.prefix(maxRecentCurrencies))
        }

        UserDefaults.standard.set(recent, forKey: recentCurrenciesKey)
    }

    /// Get symbol for currency code
    func getSymbolForCurrency(_ code: String) -> String {
        let symbols: [String: String] = [
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
            "ZAR": "R",
            "SAR": "﷼",
            "JOD": "JD",
            "AED": "د.إ"
        ]
        return symbols[code] ?? code
    }

    /// Get code for currency symbol
    func getCodeForSymbol(_ symbol: String) -> String {
        let symbolToCode: [String: String] = [
            "$": "USD",
            "€": "EUR",
            "£": "GBP",
            "¥": "JPY",
            "C$": "CAD",
            "A$": "AUD",
            "₹": "INR",
            "₽": "RUB",
            "₩": "KRW",
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
        return symbolToCode[symbol] ?? "USD"
    }

    /// Get all available currencies
    func getAllCurrencies() -> [(symbol: String, code: String, name: String)] {
        return [
            ("$", "USD", "US Dollar"),
            ("€", "EUR", "Euro"),
            ("£", "GBP", "British Pound"),
            ("¥", "JPY", "Japanese Yen"),
            ("C$", "CAD", "Canadian Dollar"),
            ("A$", "AUD", "Australian Dollar"),
            ("₹", "INR", "Indian Rupee"),
            ("₽", "RUB", "Russian Ruble"),
            ("₩", "KRW", "South Korean Won"),
            ("HK$", "HKD", "Hong Kong Dollar"),
            ("₱", "PHP", "Philippine Peso"),
            ("₺", "TRY", "Turkish Lira"),
            ("₴", "UAH", "Ukrainian Hryvnia"),
            ("₦", "NGN", "Nigerian Naira"),
            ("R", "ZAR", "South African Rand"),
            ("﷼", "SAR", "Saudi Riyal"),
            ("JD", "JOD", "Jordanian Dinar"),
            ("د.إ", "AED", "UAE Dirham")
        ]
    }
}
