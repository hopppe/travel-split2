//
//  LanguageManager.swift
//  EquiSplit
//
//  Created for Arabic localization support
//

import SwiftUI
import Foundation

/// Manages app language settings, localization, and RTL support
public class LanguageManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current app language
    @Published public var currentLanguage: SupportedLanguage {
        didSet {
            saveLanguagePreference()
            updateLayoutDirection()
        }
    }
    
    /// Current layout direction (LTR/RTL)
    @Published public var layoutDirection: LayoutDirection
    
    // MARK: - Types
    
    /// Supported languages in the app
    public enum SupportedLanguage: String, CaseIterable {
        case english = "en"
        case arabic = "ar"
        
        /// Display name for the language
        public var displayName: String {
            switch self {
            case .english:
                return "English"
            case .arabic:
                return "العربية"
            }
        }
        
        /// Native display name for the language
        public var nativeDisplayName: String {
            switch self {
            case .english:
                return "English"
            case .arabic:
                return "العربية"
            }
        }
        
        /// Layout direction for the language
        public var layoutDirection: LayoutDirection {
            switch self {
            case .english:
                return .leftToRight
            case .arabic:
                return .rightToLeft
            }
        }
        
        /// Locale identifier
        public var locale: Locale {
            return Locale(identifier: self.rawValue)
        }
    }
    
    // MARK: - Singleton
    
    public static let shared = LanguageManager()
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let languageKey = "selected_language"
    
    // MARK: - Initialization
    
    private init() {
        // Initialize with saved language or system default
        let savedLanguage = userDefaults.string(forKey: languageKey)
        
        let initialLanguage: SupportedLanguage
        if let savedLanguage = savedLanguage,
           let language = SupportedLanguage(rawValue: savedLanguage) {
            initialLanguage = language
        } else {
            initialLanguage = Self.detectSystemLanguage()
        }
        
        // Initialize layoutDirection first
        self.layoutDirection = initialLanguage.layoutDirection
        
        // Then set currentLanguage (this will trigger didSet, but layoutDirection is already initialized)
        self.currentLanguage = initialLanguage
        
        print("LanguageManager initialized with language: \(currentLanguage.rawValue)")
        print("Layout direction: \(layoutDirection)")
    }
    
    // MARK: - Public Methods
    
    /// Set the app language
    /// - Parameter language: The language to set
    public func setLanguage(_ language: SupportedLanguage) {
        print("Setting language to: \(language.rawValue)")
        currentLanguage = language
        
        // Force UI update by posting notification
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .languageDidChange, object: language)
        }
    }
    
    /// Get localized string for a key
    /// - Parameter key: The localization key
    /// - Returns: Localized string
    public func getLocalizedString(for key: String) -> String {
        guard let path = Bundle.main.path(forResource: currentLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            print("Warning: Could not find localization bundle for \(currentLanguage.rawValue)")
            return NSLocalizedString(key, comment: "")
        }
        
        let localizedString = NSLocalizedString(key, bundle: bundle, comment: "")
        
        // If the localized string is the same as the key, try fallback to English
        if localizedString == key && currentLanguage != .english {
            if let englishPath = Bundle.main.path(forResource: SupportedLanguage.english.rawValue, ofType: "lproj"),
               let englishBundle = Bundle(path: englishPath) {
                return NSLocalizedString(key, bundle: englishBundle, comment: "")
            }
        }
        
        return localizedString
    }
    
    /// Get localized string with format arguments
    /// - Parameters:
    ///   - key: The localization key
    ///   - formatArguments: Format arguments
    /// - Returns: Formatted localized string
    public func getLocalizedString(for key: String, withFormat formatArguments: [CVarArg]) -> String {
        let format = getLocalizedString(for: key)
        return String(format: format, arguments: formatArguments)
    }
    
    /// Get localized string with single format argument
    /// - Parameters:
    ///   - key: The localization key
    ///   - argument: Single format argument
    /// - Returns: Formatted localized string
    public func getLocalizedString(for key: String, withArgument argument: CVarArg) -> String {
        let format = getLocalizedString(for: key)
        return String(format: format, argument)
    }
    
    /// Check if current language is RTL
    public var isRTL: Bool {
        return layoutDirection == .rightToLeft
    }
    
    /// Get current locale
    public var currentLocale: Locale {
        return currentLanguage.locale
    }
    
    /// Reset to system language
    public func resetToSystemLanguage() {
        let systemLanguage = Self.detectSystemLanguage()
        setLanguage(systemLanguage)
    }
    
    // MARK: - Private Methods
    
    /// Detect system language preference
    /// - Returns: Detected system language or English as fallback
    private static func detectSystemLanguage() -> SupportedLanguage {
        let preferredLanguages = Locale.preferredLanguages
        print("System preferred languages: \(preferredLanguages)")
        
        for languageCode in preferredLanguages {
            // Extract base language code (e.g., "en-US" -> "en")
            let baseLanguageCode = String(languageCode.prefix(2))
            
            if let supportedLanguage = SupportedLanguage(rawValue: baseLanguageCode) {
                print("Detected system language: \(supportedLanguage.rawValue)")
                return supportedLanguage
            }
        }
        
        print("No supported system language found, defaulting to English")
        return .english
    }
    
    /// Save language preference to UserDefaults
    private func saveLanguagePreference() {
        userDefaults.set(currentLanguage.rawValue, forKey: languageKey)
        print("Saved language preference: \(currentLanguage.rawValue)")
    }
    
    /// Update layout direction based on current language
    private func updateLayoutDirection() {
        layoutDirection = currentLanguage.layoutDirection
        print("Updated layout direction: \(layoutDirection)")
    }
}

// MARK: - Extensions



// MARK: - Notifications

extension Notification.Name {
    /// Posted when language changes
    static let languageDidChange = Notification.Name("languageDidChange")
}

// MARK: - View Extensions for RTL Support

#if canImport(SwiftUI)
import SwiftUI

extension View {
    /// Apply RTL-aware leading alignment
    func leadingAlignment() -> some View {
        self.multilineTextAlignment(LanguageManager.shared.isRTL ? TextAlignment.trailing : TextAlignment.leading)
    }
    
    /// Apply RTL-aware trailing alignment  
    func trailingAlignment() -> some View {
        self.multilineTextAlignment(LanguageManager.shared.isRTL ? TextAlignment.leading : TextAlignment.trailing)
    }
    
    /// Apply environment for RTL support
    func withRTLSupport() -> some View {
        self.environment(\.layoutDirection, LanguageManager.shared.layoutDirection)
            .environment(\.locale, LanguageManager.shared.currentLocale)
    }
    
    /// Force RTL layout direction for the entire view hierarchy
    func forceRTLLayout() -> some View {
        self.environment(\.layoutDirection, LanguageManager.shared.layoutDirection)
    }
}
#endif 