//
//  SharedComponents.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// MARK: - Currency Formatter

struct CurrencyText: View {
    let amount: Double
    let symbol: String
    let color: Color
    let font: Font
    
    init(amount: Double, symbol: String = "$", color: Color = .primary, font: Font = .body) {
        self.amount = amount
        self.symbol = symbol
        self.color = color
        self.font = font
    }
    
    var body: some View {
        Text("\(symbol)\(String(format: "%.2f", amount))")
            .foregroundColor(color)
            .font(font)
    }
}

// MARK: - Empty State Views

struct EmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String
    let buttonText: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: action) {
                Text(buttonText)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.top, 8)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
    }
}

// MARK: - Participant Avatar

struct ParticipantAvatar: View {
    let participant: User
    let size: CGFloat
    
    init(participant: User, size: CGFloat = 40) {
        self.participant = participant
        self.size = size
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(participant.isClaimed ? Color.accentColor.opacity(0.2) : Color.orange.opacity(0.2))
                .frame(width: size, height: size)
            
            Text(String(participant.name.prefix(1)))
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundColor(participant.isClaimed ? .accentColor : .orange)
        }
    }
}

// MARK: - Floating Action Button

struct FloatingActionButton: View {
    let systemImage: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 60, height: 60)
                .background(Color.accentColor)
                .cornerRadius(30)
                .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - Badge View

struct BadgeView: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Section Header

struct SectionHeaderView: View {
    let title: String
    let systemImage: String?
    
    init(title: String, systemImage: String? = nil) {
        self.title = title
        self.systemImage = systemImage
    }
    
    var body: some View {
        HStack(spacing: 8) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundColor(.secondary)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Expense Card

struct ExpenseCardView: View {
    let expense: Expense
    let participants: [User]
    let onTap: () -> Void
    
    private var payer: User? {
        participants.first { $0.id == expense.paidBy.id }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(expense.title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if let payer = payer {
                            Text("Paid by \(payer.name)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    CurrencyText(
                        amount: expense.amount,
                        symbol: "$",
                        font: .headline
                    )
                }
                
                HStack {
                    Text(formatDate(expense.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(expense.shares.count) participants")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// MARK: - Helpers

enum ExpenseSplitType {
    case equal
    case custom
}

// Format currency with the given symbol
func formatCurrency(_ amount: Double, symbol: String = "$") -> String {
    return "\(symbol)\(String(format: "%.2f", amount))"
} 