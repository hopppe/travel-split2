//
//  String+Localization.swift
//  EquiSplit
//
//  Created for Arabic localization support
//

import Foundation
import SwiftUI
import TravelSplitServices

// MARK: - String Extension for Basic Localization
extension String {
    /// Returns the localized string for the current key using our custom LanguageManager
    public var localized: String {
        return LanguageManager.shared.getLocalizedString(for: self)
    }
    
    /// Returns the localized string with arguments using our custom LanguageManager
    public func localized(with arguments: CVarArg...) -> String {
        let format = LanguageManager.shared.getLocalizedString(for: self)
        return String(format: format, arguments: arguments)
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
// Skip: Extensions with constructors are not supported for external types
// Using LocalizedText view instead

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
    public func stableLocalized() -> some View {
        self.modifier(StableLanguageAwareModifier())
    }
    
    /// Apply RTL-aware text alignment
    public func rtlAwareAlignment(_ alignment: TextAlignment? = nil) -> some View {
        self.modifier(RTLAwareTextModifier(alignment: alignment))
    }
    
    /// Get the appropriate text alignment for current language
    var languageAwareAlignment: TextAlignment {
        LanguageManager.shared.isRTL ? .trailing : .leading
    }
    
    /// Get the appropriate horizontal alignment for current language
    public var languageAwareHorizontalAlignment: HorizontalAlignment {
        LanguageManager.shared.isRTL ? .trailing : .leading
    }
    
    /// Apply comprehensive RTL layout support
    public func forceRTL() -> some View {
        self.modifier(ForceRTLModifier())
    }
    
    /// Apply RTL support specifically for text fields
    func rtlTextField() -> some View {
        self.modifier(RTLTextFieldModifier())
    }
    
    /// Apply RTL support for HStack layouts
    public func rtlHStack() -> some View {
        self.modifier(RTLHStackModifier())
    }
    
    /// Apply safe RTL support for text fields (preserves text direction)
    public func safeRTLTextField() -> some View {
        self.modifier(SafeRTLTextFieldModifier())
    }
} 