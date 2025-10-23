//
//  CurrencyConverterService.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import Foundation

// MARK: - Currency Converter Service

/// Service for handling currency conversions with ECB (European Central Bank) integration
/// Uses a three-tier fallback system:
/// 1. ECB live rates (fetched from European Central Bank)
/// 2. Cached ECB rates (stored locally)
/// 3. Hardcoded fallback rates (for extreme offline scenarios)
class CurrencyConverterService {

    // Singleton instance
    static let shared = CurrencyConverterService()

    // Private constructor for singleton
    private init() {
        loadCachedRates()
    }

    // MARK: - Properties

    /// ECB API endpoint for daily exchange rates
    private let ecbURL = "https://www.ecb.europa.eu/stats/eurofxref/eurofxref-daily.xml"

    /// Cache file path for storing fetched rates
    private var cacheFileURL: URL {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentDirectory.appendingPathComponent("ecb_currency_rates.json")
    }

    /// Cached exchange rates (EUR-based from ECB)
    private var cachedRates: [String: Double] = [:]

    /// Date of last cache update
    private var lastCacheDate: Date?

    /// Currencies pegged to USD (fixed rates that never change)
    /// These currencies maintain a fixed exchange rate to USD
    /// We'll convert through USD for these instead of using ECB's EUR-based rates
    private let usdPeggedCurrencies: [String: Double] = [
        "SAR": 3.75,     // Saudi Riyal (pegged at 3.75 SAR = 1 USD)
        "JOD": 0.709,    // Jordanian Dinar (pegged at 0.709 JOD = 1 USD)
        "AED": 3.6725    // UAE Dirham (pegged at 3.6725 AED = 1 USD)
    ]

    /// Hardcoded fallback exchange rates (EUR-based, matching ECB structure)
    private let fallbackRates: [String: Double] = [
        "EUR": 1.0,      // Euro (base currency)
        "USD": 1.0855,   // US Dollar
        "GBP": 0.8344,   // British Pound
        "JPY": 151.84,   // Japanese Yen
        "CAD": 1.3569,   // Canadian Dollar
        "AUD": 1.4649,   // Australian Dollar
        "CHF": 0.9228,   // Swiss Franc
        "INR": 94.40,    // Indian Rupee
        "RUB": 73.0,     // Russian Ruble
        "KRW": 1247.0,   // South Korean Won
        "HKD": 8.44,     // Hong Kong Dollar
        "PHP": 54.0,     // Philippine Peso
        "TRY": 48.67,    // Turkish Lira
        "UAH": 27.0,     // Ukrainian Hryvnia
        "NGN": 410.0,    // Nigerian Naira
        "ZAR": 15.73,    // South African Rand
        "SAR": 4.07,     // Saudi Riyal
        "JOD": 0.77,     // Jordanian Dinar
        "AED": 3.99,     // UAE Dirham
        "CNY": 7.61,     // Chinese Yuan
        "BRL": 5.75,     // Brazilian Real
        "SEK": 10.05,    // Swedish Krona
        "NOK": 10.72,    // Norwegian Krone
        "DKK": 6.87,     // Danish Krone
        "PLN": 3.90,     // Polish Zloty
        "CZK": 22.37,    // Czech Koruna
        "HUF": 358.5,    // Hungarian Forint
        "RON": 4.68,     // Romanian Leu
        "BGN": 1.9558,   // Bulgarian Lev
        "ISK": 130.5,    // Icelandic Króna
        "NZD": 1.60,     // New Zealand Dollar
        "SGD": 1.46,     // Singapore Dollar
        "THB": 35.8,     // Thai Baht
        "MYR": 4.84,     // Malaysian Ringgit
        "IDR": 17735.0,  // Indonesian Rupiah
        "ILS": 3.53,     // Israeli Shekel
        "MXN": 21.93     // Mexican Peso
    ]

    // MARK: - Public Methods

    /// Convert amount from one currency to another
    /// - Parameters:
    ///   - amount: Amount to convert
    ///   - fromCurrency: Source currency code (e.g., "USD")
    ///   - toCurrency: Target currency code (e.g., "EUR")
    /// - Returns: Converted amount
    func convert(amount: Double, from fromCurrency: String, to toCurrency: String) -> Double {
        // If same currency, no conversion needed
        if fromCurrency == toCurrency {
            return amount
        }

        // Get exchange rates (try cache first, then fallback)
        let rates = cachedRates.isEmpty ? fallbackRates : cachedRates

        // Check if either currency is USD-pegged
        let isFromPegged = usdPeggedCurrencies[fromCurrency] != nil
        let isToPegged = usdPeggedCurrencies[toCurrency] != nil

        // Special handling for USD-pegged currencies
        // Path: fromCurrency → USD → toCurrency (using fixed USD peg rates)
        if isFromPegged || isToPegged {
            return convertWithUSDPeg(amount: amount, from: fromCurrency, to: toCurrency, rates: rates)
        }

        // Both currencies are EUR - no conversion needed
        if fromCurrency == "EUR" && toCurrency == "EUR" {
            return amount
        }

        // Direct conversion from EUR
        if fromCurrency == "EUR" {
            guard let toRate = rates[toCurrency] else {
                print("⚠️ Currency not found: \(toCurrency), returning original amount")
                return amount
            }
            return amount * toRate
        }

        // Direct conversion to EUR
        if toCurrency == "EUR" {
            guard let fromRate = rates[fromCurrency] else {
                print("⚠️ Currency not found: \(fromCurrency), returning original amount")
                return amount
            }
            return amount / fromRate
        }

        // Cross-rate conversion (both non-EUR)
        // Formula: amount * (EUR/fromCurrency) * (toCurrency/EUR)
        guard let fromRate = rates[fromCurrency],
              let toRate = rates[toCurrency] else {
            print("⚠️ One or both currencies not found: \(fromCurrency) -> \(toCurrency)")
            return amount
        }

        // Convert to EUR first, then to target currency
        let amountInEUR = amount / fromRate
        return amountInEUR * toRate
    }

    /// Convert currencies using USD as intermediary for pegged currencies
    /// Path: fromCurrency → EUR → USD → toCurrency
    private func convertWithUSDPeg(amount: Double, from fromCurrency: String, to toCurrency: String, rates: [String: Double]) -> Double {
        // Get USD rate from ECB (EUR-based)
        guard let usdRate = rates["USD"] else {
            print("⚠️ USD rate not available, using fallback")
            return amount
        }

        var amountInUSD: Double

        // Convert FROM currency to USD
        if let pegRate = usdPeggedCurrencies[fromCurrency] {
            // From pegged currency to USD (e.g., SAR → USD)
            amountInUSD = amount / pegRate
        } else if fromCurrency == "USD" {
            // Already in USD
            amountInUSD = amount
        } else {
            // Convert from other currency through EUR to USD
            // e.g., GBP → EUR → USD
            guard let fromRate = rates[fromCurrency] else {
                print("⚠️ Currency not found: \(fromCurrency)")
                return amount
            }
            let amountInEUR = amount / fromRate
            amountInUSD = amountInEUR * usdRate
        }

        // Convert FROM USD to target currency
        if let pegRate = usdPeggedCurrencies[toCurrency] {
            // From USD to pegged currency (e.g., USD → SAR)
            return amountInUSD * pegRate
        } else if toCurrency == "USD" {
            // Already in USD
            return amountInUSD
        } else {
            // Convert from USD through EUR to target currency
            // e.g., USD → EUR → GBP
            guard let toRate = rates[toCurrency] else {
                print("⚠️ Currency not found: \(toCurrency)")
                return amount
            }
            let amountInEUR = amountInUSD / usdRate
            return amountInEUR * toRate
        }
    }

    /// Fetch latest exchange rates from ECB
    /// This is triggered when a user creates an expense
    func fetchLatestRates(completion: ((Bool) -> Void)? = nil) {
        // Check if we need to fetch (only once per day)
        if let lastDate = lastCacheDate,
           Calendar.current.isDateInToday(lastDate) {
            print("✅ Using cached rates from today")
            completion?(true)
            return
        }

        print("📡 Fetching latest rates from ECB...")

        guard let url = URL(string: ecbURL) else {
            print("❌ Invalid ECB URL")
            completion?(false)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }

            if let error = error {
                print("❌ Error fetching ECB rates: \(error.localizedDescription)")
                completion?(false)
                return
            }

            guard let data = data else {
                print("❌ No data received from ECB")
                completion?(false)
                return
            }

            // Parse XML
            self.parseECBRates(data: data) { success in
                completion?(success)
            }
        }.resume()
    }

    /// Get all available currency codes
    func getAllCurrencyCodes() -> [String] {
        let rates = cachedRates.isEmpty ? fallbackRates : cachedRates
        return Array(rates.keys).sorted()
    }

    /// Currency information structure
    struct CurrencyInfo {
        let code: String
        let symbol: String
        let name: String
        let flag: String
    }

    /// Get all available currency information
    func getAllCurrencies() -> [CurrencyInfo] {
        let currencyData: [String: (symbol: String, name: String, flag: String)] = [
            "USD": ("$", "US Dollar", "🇺🇸"),
            "EUR": ("€", "Euro", "🇪🇺"),
            "GBP": ("£", "British Pound", "🇬🇧"),
            "JPY": ("¥", "Japanese Yen", "🇯🇵"),
            "CAD": ("C$", "Canadian Dollar", "🇨🇦"),
            "AUD": ("A$", "Australian Dollar", "🇦🇺"),
            "CHF": ("CHF", "Swiss Franc", "🇨🇭"),
            "INR": ("₹", "Indian Rupee", "🇮🇳"),
            "RUB": ("₽", "Russian Ruble", "🇷🇺"),
            "KRW": ("₩", "South Korean Won", "🇰🇷"),
            "HKD": ("HK$", "Hong Kong Dollar", "🇭🇰"),
            "PHP": ("₱", "Philippine Peso", "🇵🇭"),
            "TRY": ("₺", "Turkish Lira", "🇹🇷"),
            "UAH": ("₴", "Ukrainian Hryvnia", "🇺🇦"),
            "NGN": ("₦", "Nigerian Naira", "🇳🇬"),
            "ZAR": ("R", "South African Rand", "🇿🇦"),
            "SAR": ("﷼", "Saudi Riyal", "🇸🇦"),
            "JOD": ("JD", "Jordanian Dinar", "🇯🇴"),
            "AED": ("د.إ", "UAE Dirham", "🇦🇪"),
            "CNY": ("¥", "Chinese Yuan", "🇨🇳"),
            "BRL": ("R$", "Brazilian Real", "🇧🇷"),
            "SEK": ("kr", "Swedish Krona", "🇸🇪"),
            "NOK": ("kr", "Norwegian Krone", "🇳🇴"),
            "DKK": ("kr", "Danish Krone", "🇩🇰"),
            "PLN": ("zł", "Polish Zloty", "🇵🇱"),
            "CZK": ("Kč", "Czech Koruna", "🇨🇿"),
            "HUF": ("Ft", "Hungarian Forint", "🇭🇺"),
            "RON": ("lei", "Romanian Leu", "🇷🇴"),
            "BGN": ("лв", "Bulgarian Lev", "🇧🇬"),
            "ISK": ("kr", "Icelandic Króna", "🇮🇸"),
            "NZD": ("NZ$", "New Zealand Dollar", "🇳🇿"),
            "SGD": ("S$", "Singapore Dollar", "🇸🇬"),
            "THB": ("฿", "Thai Baht", "🇹🇭"),
            "MYR": ("RM", "Malaysian Ringgit", "🇲🇾"),
            "IDR": ("Rp", "Indonesian Rupiah", "🇮🇩"),
            "ILS": ("₪", "Israeli Shekel", "🇮🇱"),
            "MXN": ("$", "Mexican Peso", "🇲🇽")
        ]

        // Merge cached rates with fallback rates - always include fallback currencies
        // This ensures currencies like SAR and JOD (pegged to USD) are always available
        var allRates = fallbackRates
        if !cachedRates.isEmpty {
            // Override with cached rates if available
            for (code, rate) in cachedRates {
                allRates[code] = rate
            }
        }

        return allRates.keys.sorted().compactMap { code in
            guard let data = currencyData[code] else { return nil }
            return CurrencyInfo(
                code: code,
                symbol: data.symbol,
                name: data.name,
                flag: data.flag
            )
        }
    }

    /// Get all available currency symbols with codes (legacy compatibility)
    func getAllCurrencySymbolsWithCodes() -> [(symbol: String, code: String)] {
        return getAllCurrencies().map { (symbol: $0.symbol, code: $0.code) }
    }

    /// Get just the currency symbols for simple pickers
    func getAllCurrencySymbols() -> [String] {
        return getAllCurrencies().map { $0.symbol }
    }

    /// Get currency info by symbol
    func getCurrencyInfo(forSymbol symbol: String) -> CurrencyInfo? {
        return getAllCurrencies().first { $0.symbol == symbol }
    }

    /// Get currency info by code
    func getCurrencyInfo(forCode code: String) -> CurrencyInfo? {
        return getAllCurrencies().first { $0.code == code }
    }

    // MARK: - Private Methods

    /// Parse ECB XML response and update cache
    private func parseECBRates(data: Data, completion: @escaping (Bool) -> Void) {
        let parser = ECBXMLParser()

        if let rates = parser.parse(data: data) {
            // Add EUR as base currency (always 1.0)
            var updatedRates = rates
            updatedRates["EUR"] = 1.0

            // Update cache
            self.cachedRates = updatedRates
            self.lastCacheDate = Date()

            // Save to disk
            self.saveCachedRates()

            print("✅ Successfully fetched and cached \(updatedRates.count) currency rates from ECB")
            completion(true)
        } else {
            print("❌ Failed to parse ECB XML")
            completion(false)
        }
    }

    /// Save cached rates to disk
    private func saveCachedRates() {
        let cacheData: [String: Any] = [
            "rates": cachedRates,
            "date": lastCacheDate?.timeIntervalSince1970 ?? 0
        ]

        do {
            let data = try JSONSerialization.data(withJSONObject: cacheData)
            try data.write(to: cacheFileURL)
            print("💾 Saved currency rates to cache")
        } catch {
            print("❌ Error saving currency cache: \(error.localizedDescription)")
        }
    }

    /// Load cached rates from disk
    private func loadCachedRates() {
        guard FileManager.default.fileExists(atPath: cacheFileURL.path) else {
            print("ℹ️ No cached rates found, will use fallback rates")
            return
        }

        do {
            let data = try Data(contentsOf: cacheFileURL)
            if let cacheData = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let rates = cacheData["rates"] as? [String: Double],
               let timestamp = cacheData["date"] as? TimeInterval {

                cachedRates = rates
                lastCacheDate = Date(timeIntervalSince1970: timestamp)

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .short
                print("💾 Loaded cached rates from \(dateFormatter.string(from: lastCacheDate!))")
            }
        } catch {
            print("❌ Error loading currency cache: \(error.localizedDescription)")
        }
    }
}

// MARK: - ECB XML Parser

/// Parser for ECB's daily exchange rate XML feed
private class ECBXMLParser: NSObject, XMLParserDelegate {
    private var rates: [String: Double] = [:]

    func parse(data: Data) -> [String: Double]? {
        let parser = XMLParser(data: data)
        parser.delegate = self

        if parser.parse() {
            return rates
        }
        return nil
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == "Cube" {
            if let currency = attributeDict["currency"],
               let rateString = attributeDict["rate"],
               let rate = Double(rateString) {
                rates[currency] = rate
            }
        }
    }
} 