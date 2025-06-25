//
//  Models.swift
//  Split Pro
//
//  Created by Ethan Hoppe on 3/5/25.
//

import Foundation

// MARK: - User Model
struct User: Identifiable, Codable, Equatable, Hashable {
    var id: String // Unique identifier 
    var name: String
    var email: String
    var profileImage: String? // URL or asset name for profile image
    var isClaimed: Bool = true // Whether this participant has been claimed by a real user
    var claimedByUserId: String? // ID of the user who claimed this participant (if any)
    
    // For creating a new user (a claimed user - real app user)
    static func create(name: String, email: String) -> User {
        // Try to get Firebase ID if available
        if let firebaseUserId = FirebaseService.shared.getCurrentUserId() {
            print("Creating user with Firebase ID: \(firebaseUserId)")
            return User(id: firebaseUserId, name: name, email: email, profileImage: nil, isClaimed: true)
        } else {
            // Fall back to UUID if no Firebase ID is available
            let uuid = UUID().uuidString
            print("Creating user with UUID: \(uuid) (no Firebase ID available)")
            return User(id: uuid, name: name, email: email, profileImage: nil, isClaimed: true)
        }
    }
    
    // For creating a placeholder participant that can be claimed later
    static func createUnclaimed(name: String, email: String = "") -> User {
        // Generate a special ID format that links this unclaimed user to the authenticated user
        // This helps with Firestore permissions
        let id = FirebaseService.shared.generateUnclaimedParticipantId(name: name)
        return User(id: id, name: name, email: email, profileImage: nil, isClaimed: false)
    }
    
    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Trip Model
struct Trip: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var startDate: Date?
    var endDate: Date?
    var participants: [User]
    var expenses: [Expense]
    var inviteCode: String // Shareable code for inviting others
    var baseCurrencyCode: String // Base currency for balance calculations
    
    // For creating a new trip
    static func create(name: String, description: String, creator: User) -> Trip {
        return Trip(
            id: UUID().uuidString,
            name: name,
            description: description,
            startDate: nil,
            endDate: nil,
            participants: [creator],
            expenses: [],
            inviteCode: String(UUID().uuidString.prefix(8)), // Create shortened invite code
            baseCurrencyCode: "USD" // Default to USD
        )
    }
    
    // Computed property for base currency symbol
    var baseCurrencySymbol: String {
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
            "ZAR": "R",
            "SAR": "﷼"
        ]
        return symbols[baseCurrencyCode] ?? "$"
    }
    
    // Calculate what each person owes to each other
    func calculateDebts() -> [Debt] {
        var balances: [String: Double] = [:] // User ID to their balance
        var debts: [Debt] = []
        
        // Initialize balances for all participants
        for participant in participants {
            balances[participant.id] = 0.0
        }
        
        // Calculate what each person has paid and what they owe
        for expense in expenses {
            let expenseCurrency = expense.currencyCode ?? "USD"
            
            // Convert expense amount to base currency
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: baseCurrencyCode
            )
            
            // Add the amount to the payer
            balances[expense.paidBy.id, default: 0] += convertedAmount
            
            // Subtract the amount from each participant based on their share
            for share in expense.shares {
                // Convert share amount to base currency
                let convertedShareAmount = CurrencyConverterService.shared.convert(
                    amount: share.amount,
                    from: expenseCurrency,
                    to: baseCurrencyCode
                )
                balances[share.user.id, default: 0] -= convertedShareAmount
            }
        }
        
        // Clean up balances - remove any IDs that don't exist in current participants
        let participantIds = Set(participants.map { $0.id })
        for balanceId in balances.keys {
            if !participantIds.contains(balanceId) {
                print("Warning: Removing balance for non-existent participant ID: \(balanceId)")
                balances.removeValue(forKey: balanceId)
            }
        }
        
        // Simplify and create debts
        while let creditor = balances.max(by: { $0.value < $1.value }),
              let debtor = balances.min(by: { $0.value < $1.value }),
              creditor.value > 0.01, debtor.value < -0.01 {
            
            // Safely find the creditor and debtor users
            guard let creditorUser = participants.first(where: { $0.id == creditor.key }),
                  let debtorUser = participants.first(where: { $0.id == debtor.key }) else {
                // If we can't find the user, remove them from balances and continue
                print("Warning: Could not find user with ID \(creditor.key) or \(debtor.key) in participants. Removing from balances.")
                balances.removeValue(forKey: creditor.key)
                balances.removeValue(forKey: debtor.key)
                continue
            }
            
            let amount = min(abs(debtor.value), creditor.value)
            debts.append(Debt(
                from: debtorUser,
                to: creditorUser,
                amount: amount
            ))
            
            // Update balances
            balances[creditor.key, default: 0] -= amount
            balances[debtor.key, default: 0] += amount
        }
        
        return debts
    }
}

// MARK: - Expense Model
struct Expense: Identifiable, Codable {
    let id: String
    var title: String
    var description: String
    var amount: Double
    var date: Date
    var category: ExpenseCategory
    var paidBy: User
    var shares: [ExpenseShare]
    var currencyCode: String?
    
    // Computed property for currency symbol
    var currencySymbol: String {
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
            "ZAR": "R",
            "SAR": "﷼"
        ]
        return symbols[currencyCode ?? "USD"] ?? "$"
    }
    
    // For creating a new expense with equal splits
    static func createEqual(title: String, amount: Double, paidBy: User, participants: [User], date: Date = Date(), category: ExpenseCategory = .other, currencyCode: String = "USD") -> Expense {
        
        let equalAmount = amount / Double(participants.count)
        let shares = participants.map { user in
            ExpenseShare(user: user, amount: equalAmount, percentage: 100.0 / Double(participants.count))
        }
        
        return Expense(
            id: UUID().uuidString,
            title: title,
            description: "",
            amount: amount,
            date: date,
            category: category,
            paidBy: paidBy,
            shares: shares,
            currencyCode: currencyCode
        )
    }
    
    // For creating a custom split expense
    static func createCustom(title: String, amount: Double, paidBy: User, shares: [ExpenseShare], date: Date = Date(), category: ExpenseCategory = .other, currencyCode: String = "USD") -> Expense {
        
        return Expense(
            id: UUID().uuidString,
            title: title,
            description: "",
            amount: amount,
            date: date,
            category: category,
            paidBy: paidBy,
            shares: shares,
            currencyCode: currencyCode
        )
    }
}

// MARK: - Expense Share Model
struct ExpenseShare: Codable, Equatable {
    var user: User
    var amount: Double
    var percentage: Double
    
    static func == (lhs: ExpenseShare, rhs: ExpenseShare) -> Bool {
        return lhs.user.id == rhs.user.id && 
               lhs.amount == rhs.amount &&
               lhs.percentage == rhs.percentage
    }
}

// MARK: - Debt Model
struct Debt: Identifiable {
    var id: String { UUID().uuidString }
    var from: User
    var to: User
    var amount: Double
}

// MARK: - Expense Categories
enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case transportation = "Transportation"
    case accommodation = "Accommodation"
    case activities = "Activities"
    case shopping = "Shopping"
    case other = "Other"
    
    var id: String { self.rawValue }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transportation: return "car.fill"
        case .accommodation: return "house.fill"
        case .activities: return "ticket.fill"
        case .shopping: return "bag.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
} 