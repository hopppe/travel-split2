//
//  HapticManager.swift
//  EquiSplit
//
//  Created for enhanced user feedback
//

import UIKit

/// Manages haptic feedback throughout the app for better tactile experience
class HapticManager {
    static let shared = HapticManager()

    private init() {}

    /// Triggers a success haptic (expense added, payment recorded, etc.)
    func success() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    /// Triggers an error haptic (operation failed, validation error)
    func error() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }

    /// Triggers a warning haptic (leaving group with balance, confirmation needed)
    func warning() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
    }

    /// Triggers an impact haptic (button press, toggle)
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }

    /// Light impact for subtle interactions
    func lightImpact() {
        impact(.light)
    }

    /// Heavy impact for significant actions
    func heavyImpact() {
        impact(.heavy)
    }

    /// Selection changed haptic (for pickers, segmented controls)
    func selectionChanged() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
