//
//  LanguageManager.swift
//  EquiSplit
//
//  Created for Arabic localization support
//

import SwiftUI
import Foundation

/// Manages app language settings, localization, and RTL support
class LanguageManager: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current app language
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            saveLanguagePreference()
            updateLayoutDirection()
        }
    }
    
    /// Current layout direction (LTR/RTL)
    @Published var layoutDirection: LayoutDirection
    
    // MARK: - Types
    
    /// Supported languages in the app
    enum SupportedLanguage: String, CaseIterable {
        case english = "en"
        case arabic = "ar"
        
        /// Display name for the language
        var displayName: String {
            switch self {
            case .english:
                return "English"
            case .arabic:
                return "العربية"
            }
        }
        
        /// Native display name for the language
        var nativeDisplayName: String {
            switch self {
            case .english:
                return "English"
            case .arabic:
                return "العربية"
            }
        }
        
        /// Layout direction for the language
        var layoutDirection: LayoutDirection {
            switch self {
            case .english:
                return .leftToRight
            case .arabic:
                return .rightToLeft
            }
        }
        
        /// Locale identifier
        var locale: Locale {
            return Locale(identifier: self.rawValue)
        }
    }
    
    // MARK: - Singleton
    
    static let shared = LanguageManager()
    
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
    func setLanguage(_ language: SupportedLanguage) {
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
    func getLocalizedString(for key: String) -> String {
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
    ///   - arguments: Format arguments
    /// - Returns: Formatted localized string
    func getLocalizedString(for key: String, with arguments: CVarArg...) -> String {
        let format = getLocalizedString(for: key)
        return String(format: format, arguments: arguments)
    }
    
    /// Check if current language is RTL
    var isRTL: Bool {
        return layoutDirection == .rightToLeft
    }
    
    /// Get current locale
    var currentLocale: Locale {
        return currentLanguage.locale
    }
    
    /// Reset to system language
    func resetToSystemLanguage() {
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

extension View {
    /// Apply RTL-aware leading alignment
    func leadingAlignment() -> some View {
        self.multilineTextAlignment(LanguageManager.shared.isRTL ? .trailing : .leading)
    }
    
    /// Apply RTL-aware trailing alignment  
    func trailingAlignment() -> some View {
        self.multilineTextAlignment(LanguageManager.shared.isRTL ? .leading : .trailing)
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