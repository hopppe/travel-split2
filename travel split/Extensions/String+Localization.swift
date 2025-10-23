//
//  String+Localization.swift
//  EquiSplit
//
//  Created for Arabic localization support
//

import Foundation
import SwiftUI

// MARK: - String Extension for Basic Localization
extension String {
    /// Returns the localized string for the current key using our custom LanguageManager
    var localized: String {
        return LanguageManager.shared.getLocalizedString(for: self)
    }

    /// Returns the localized string with arguments using our custom LanguageManager
    func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.getLocalizedString(for: self)
        return String(format: format, arguments: arguments)
    }

    /// Converts Arabic-Indic numerals (٠١٢٣٤٥٦٧٨٩) to Western numerals (0123456789)
    /// Also handles Eastern Arabic numerals and other localized number formats
    func convertingArabicNumeralsToWestern() -> String {
        // Map of Arabic-Indic numerals to Western numerals
        let arabicToWesternMap: [Character: Character] = [
            "٠": "0", "١": "1", "٢": "2", "٣": "3", "٤": "4",
            "٥": "5", "٦": "6", "٧": "7", "٨": "8", "٩": "9",
            // Eastern Arabic numerals (used in some regions)
            "۰": "0", "۱": "1", "۲": "2", "۳": "3", "۴": "4",
            "۵": "5", "۶": "6", "۷": "7", "۸": "8", "۹": "9"
        ]

        var result = ""
        for char in self {
            if let westernChar = arabicToWesternMap[char] {
                result.append(westernChar)
            } else {
                result.append(char)
            }
        }
        return result
    }

    /// Converts string to Double, handling Arabic numerals, commas, and various decimal separators
    /// Returns nil if the string cannot be parsed as a valid number
    func toDoubleFromLocalizedNumber() -> Double? {
        // First, convert Arabic numerals to Western
        var normalized = self.convertingArabicNumeralsToWestern()

        // Trim whitespace
        normalized = normalized.trimmingCharacters(in: .whitespaces)

        // Handle empty string
        if normalized.isEmpty {
            return nil
        }

        // Replace comma decimal separator with period (for European formats)
        // But preserve comma as thousands separator if both comma and period exist
        let hasComma = normalized.contains(",")
        let hasPeriod = normalized.contains(".")

        if hasComma && hasPeriod {
            // If both exist, assume period is decimal and comma is thousands
            normalized = normalized.replacingOccurrences(of: ",", with: "")
        } else if hasComma && !hasPeriod {
            // If only comma, it's likely the decimal separator
            normalized = normalized.replacingOccurrences(of: ",", with: ".")
        }

        // Try to parse as Double
        return Double(normalized)
    }
}

// MARK: - SwiftUI Localized Text View
struct LocalizedText: View {
    private let key: String
    private let arguments: [CVarArg]
    private let alignment: TextAlignment?
    
    @ObservedObject private var languageManager = LanguageManager.shared
    
    init(_ key: String, alignment: TextAlignment? = nil) {
        self.key = key
        self.arguments = []
        self.alignment = alignment
    }
    
    init(_ key: String, arguments: CVarArg..., alignment: TextAlignment? = nil) {
        self.key = key
        self.arguments = arguments
        self.alignment = alignment
    }
    
    var body: some View {
        Text(localizedString)
            .multilineTextAlignment(textAlignment)
    }
    
    private var localizedString: String {
        let format = languageManager.getLocalizedString(for: key)
        if arguments.isEmpty {
            return format
        } else {
            return String(format: format, arguments: arguments)
        }
    }
    
    private var textAlignment: TextAlignment {
        if let alignment = alignment {
            return alignment
        }
        
        // Use RTL-appropriate alignment based on language
        return languageManager.isRTL ? .trailing : .leading
    }
}

// MARK: - Text Extension for Convenience
extension Text {
    /// Creates a Text view with localized string that automatically updates when language changes
    init(localized key: String) {
        let localizedString = LanguageManager.shared.getLocalizedString(for: key)
        self.init(localizedString)
    }
    
    /// Creates a Text view with localized string and arguments that automatically updates when language changes
    init(localized key: String, arguments: CVarArg...) {
        let format = LanguageManager.shared.getLocalizedString(for: key)
        let localizedString = String(format: format, arguments: arguments)
        self.init(localizedString)
    }
}

// MARK: - View Modifier for Language-Aware Views
struct LanguageAwareModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .environment(\.locale, languageManager.currentLocale)
            // Remove the .id() modifier to prevent view recreation and sheet dismissal
            .animation(.easeInOut(duration: 0.3), value: languageManager.layoutDirection)
    }
}

// MARK: - Stable Language-Aware Modifier for Sheets
struct StableLanguageAwareModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .environment(\.locale, languageManager.currentLocale)
            // Don't use .id() for sheets to prevent dismissal
    }
}

// MARK: - RTL Text Alignment Modifier
struct RTLAwareTextModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    private let forceAlignment: TextAlignment?
    
    init(alignment: TextAlignment? = nil) {
        self.forceAlignment = alignment
    }
    
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(textAlignment)
    }
    
    private var textAlignment: TextAlignment {
        if let forceAlignment = forceAlignment {
            return forceAlignment
        }
        return languageManager.isRTL ? .trailing : .leading
    }
}

// MARK: - Comprehensive RTL Layout Modifier
struct ForceRTLModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        // Only apply RTL layout when Arabic is selected
        if languageManager.isRTL {
            content
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, languageManager.currentLocale)
        } else {
            content
                .environment(\.layoutDirection, .leftToRight)
                .environment(\.locale, languageManager.currentLocale)
        }
    }
}

// MARK: - TextField RTL Modifier  
struct RTLTextFieldModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        content
            .multilineTextAlignment(languageManager.isRTL ? .trailing : .leading)
            .environment(\.layoutDirection, languageManager.layoutDirection)
            .environment(\.locale, languageManager.currentLocale)
    }
}

// MARK: - Safe RTL TextField Modifier (preserves text direction)
struct SafeRTLTextFieldModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        // Only apply RTL behavior when Arabic is selected
        if languageManager.isRTL {
            content
                .multilineTextAlignment(.trailing)
        } else {
            content
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - HStack RTL Modifier
struct RTLHStackModifier: ViewModifier {
    @ObservedObject private var languageManager = LanguageManager.shared
    
    func body(content: Content) -> some View {
        // Only apply RTL layout when Arabic is selected
        if languageManager.isRTL {
            content
                .environment(\.layoutDirection, .rightToLeft)
                .environment(\.locale, languageManager.currentLocale)
        } else {
            content
                .environment(\.layoutDirection, .leftToRight)
                .environment(\.locale, languageManager.currentLocale)
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply language-aware modifications including layout direction
    func localized() -> some View {
        self.modifier(LanguageAwareModifier())
    }
    
    /// Apply stable language-aware modifications for sheets (prevents dismissal)
    func stableLocalized() -> some View {
        self.modifier(StableLanguageAwareModifier())
    }
    
    /// Apply RTL-aware text alignment
    func rtlAwareAlignment(_ alignment: TextAlignment? = nil) -> some View {
        self.modifier(RTLAwareTextModifier(alignment: alignment))
    }
    
    /// Get the appropriate text alignment for current language
    var languageAwareAlignment: TextAlignment {
        LanguageManager.shared.isRTL ? .trailing : .leading
    }
    
    /// Get the appropriate horizontal alignment for current language
    var languageAwareHorizontalAlignment: HorizontalAlignment {
        LanguageManager.shared.isRTL ? .trailing : .leading
    }
    
    /// Apply comprehensive RTL layout support
    func forceRTL() -> some View {
        self.modifier(ForceRTLModifier())
    }
    
    /// Apply RTL support specifically for text fields
    func rtlTextField() -> some View {
        self.modifier(RTLTextFieldModifier())
    }
    
    /// Apply RTL support for HStack layouts
    func rtlHStack() -> some View {
        self.modifier(RTLHStackModifier())
    }
    
    /// Apply safe RTL support for text fields (preserves text direction)
    func safeRTLTextField() -> some View {
        self.modifier(SafeRTLTextFieldModifier())
    }
} 