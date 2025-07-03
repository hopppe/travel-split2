//
//  Models.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
// 

import Foundation

// MARK: - User Model
public struct User: Identifiable, Codable, Equatable, Hashable {
    public var id: String // Unique identifier 
    public var name: String
    public var email: String
    public var profileImage: String? // URL or asset name for profile image
    public var isClaimed: Bool = true // Whether this participant has been claimed by a real user
    public var claimedByUserId: String? // ID of the user who claimed this participant (if any)
    
    public init(id: String, name: String, email: String, profileImage: String? = nil, isClaimed: Bool = true, claimedByUserId: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.profileImage = profileImage
        self.isClaimed = isClaimed
        self.claimedByUserId = claimedByUserId
    }
    
    // For creating a new user (a claimed user - real app user)
    public static func create(name: String, email: String, userId: String? = nil) -> User {
        // Use provided ID or generate UUID
        let id = userId ?? UUID().uuidString
        print("Creating user with ID: \(id)")
        return User(id: id, name: name, email: email, profileImage: nil, isClaimed: true)
    }
    
    // For creating a placeholder participant that can be claimed later
    public static func createUnclaimed(name: String, email: String = "", authUserId: String? = nil) -> User {
        // Generate a special ID format that links this unclaimed user to the authenticated user
        // This helps with Firestore permissions
        let authId = authUserId ?? "no_auth"
        let randomPart = UUID().uuidString.prefix(8)
        let sanitizedName = name.lowercased().replacingOccurrences(of: " ", with: "_")
        let id = "unclaimed_\(authId)_\(randomPart)_\(sanitizedName)"
        return User(id: id, name: name, email: email, profileImage: nil, isClaimed: false)
    }
    
    // Hashable conformance
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Trip Model
public struct Trip: Identifiable, Codable {
    public let id: String
    public var name: String
    public var description: String
    public var startDate: Date?
    public var endDate: Date?
    public var participants: [User]
    public var expenses: [Expense]
    public var inviteCode: String // Shareable code for inviting others
    public var baseCurrencyCode: String // Base currency for balance calculations
    
    public init(id: String, name: String, description: String, startDate: Date? = nil, endDate: Date? = nil, participants: [User], expenses: [Expense], inviteCode: String, baseCurrencyCode: String) {
        self.id = id
        self.name = name
        self.description = description
        self.startDate = startDate
        self.endDate = endDate
        self.participants = participants
        self.expenses = expenses
        self.inviteCode = inviteCode
        self.baseCurrencyCode = baseCurrencyCode
    }
    
    // For creating a new trip
    public static func create(name: String, description: String, creator: User) -> Trip {
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
    public var baseCurrencySymbol: String {
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
    public func calculateDebts(currencyConverter: ((Double, String, String) -> Double)? = nil) -> [Debt] {
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
            let convertedAmount: Double
            if let converter = currencyConverter {
                convertedAmount = converter(expense.amount, expenseCurrency, baseCurrencyCode)
            } else {
                // Fallback - assume same currency or no conversion needed
                convertedAmount = expense.amount
            }
            
            // Add the amount to the payer
            balances[expense.paidBy.id, default: 0] += convertedAmount
            
            // Subtract the amount from each participant based on their share
            for share in expense.shares {
                // Convert share amount to base currency
                let convertedShareAmount: Double
                if let converter = currencyConverter {
                    convertedShareAmount = converter(share.amount, expenseCurrency, baseCurrencyCode)
                } else {
                    // Fallback - assume same currency or no conversion needed
                    convertedShareAmount = share.amount
                }
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
public struct Expense: Identifiable, Codable {
    public let id: String
    public var title: String
    public var description: String
    public var amount: Double
    public var date: Date
    public var category: ExpenseCategory
    public var paidBy: User
    public var shares: [ExpenseShare]
    public var currencyCode: String?
    
    public init(id: String, title: String, description: String, amount: Double, date: Date, category: ExpenseCategory, paidBy: User, shares: [ExpenseShare], currencyCode: String? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.amount = amount
        self.date = date
        self.category = category
        self.paidBy = paidBy
        self.shares = shares
        self.currencyCode = currencyCode
    }
    
    // Computed property for currency symbol
    public var currencySymbol: String {
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
            "SAR": "﷼",
            "JOD": "JD",
            "AED": "د.إ"
        ]
        return symbols[currencyCode ?? "USD"] ?? "$"
    }
    
    // For creating a new expense with equal splits
    public static func createEqual(title: String, amount: Double, paidBy: User, participants: [User], date: Date = Date(), category: ExpenseCategory = .other, currencyCode: String = "USD") -> Expense {
        
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
    public static func createCustom(title: String, amount: Double, paidBy: User, shares: [ExpenseShare], date: Date = Date(), category: ExpenseCategory = .other, currencyCode: String = "USD") -> Expense {
        
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
public struct ExpenseShare: Codable, Equatable {
    public var user: User
    public var amount: Double
    public var percentage: Double
    
    public init(user: User, amount: Double, percentage: Double) {
        self.user = user
        self.amount = amount
        self.percentage = percentage
    }
    
    public static func == (lhs: ExpenseShare, rhs: ExpenseShare) -> Bool {
        return lhs.user.id == rhs.user.id && 
               lhs.amount == rhs.amount &&
               lhs.percentage == rhs.percentage
    }
}

// MARK: - Debt Model
public struct Debt: Identifiable {
    public var id: String { UUID().uuidString }
    public var from: User
    public var to: User
    public var amount: Double
    
    public init(from: User, to: User, amount: Double) {
        self.from = from
        self.to = to
        self.amount = amount
    }
}

// MARK: - Expense Categories
public enum ExpenseCategory: String, Codable, CaseIterable, Identifiable {
    case food = "Food"
    case transportation = "Transportation"
    case accommodation = "Accommodation"
    case activities = "Activities"
    case shopping = "Shopping"
    case other = "Other"
    
    public var id: String { self.rawValue }
    
    public var icon: String {
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