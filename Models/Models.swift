import Foundation

// MARK: - User Model
struct User: Identifiable, Codable, Equatable, Hashable {
    let id: String // Unique identifier 
    var name: String
    var email: String
    var profileImage: String? // URL or asset name for profile image
    
    // For creating a new user
    static func create(name: String, email: String) -> User {
        return User(id: UUID().uuidString, name: name, email: email, profileImage: nil)
    }
    
    // Explicit Hashable implementation
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: User, rhs: User) -> Bool {
        return lhs.id == rhs.id
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
            inviteCode: String(UUID().uuidString.prefix(8)) // Create shortened invite code
        )
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
            // Add the amount to the payer
            balances[expense.paidBy.id, default: 0] += expense.amount
            
            // Subtract the amount from each participant based on their share
            for share in expense.shares {
                balances[share.user.id, default: 0] -= share.amount
            }
        }
        
        // Simplify and create debts
        while let creditor = balances.max(by: { $0.value < $1.value }),
              let debtor = balances.min(by: { $0.value < $1.value }),
              creditor.value > 0.01, debtor.value < -0.01 {
            
            let creditorUser = participants.first(where: { $0.id == creditor.key })!
            let debtorUser = participants.first(where: { $0.id == debtor.key })!
            
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
    
    // For creating a new expense with equal splits
    static func createEqual(title: String, amount: Double, paidBy: User, participants: [User], date: Date = Date(), category: ExpenseCategory = .other) -> Expense {
        
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
            shares: shares
        )
    }
    
    // For creating a custom split expense
    static func createCustom(title: String, amount: Double, paidBy: User, shares: [ExpenseShare], date: Date = Date(), category: ExpenseCategory = .other) -> Expense {
        
        return Expense(
            id: UUID().uuidString,
            title: title,
            description: "",
            amount: amount,
            date: date,
            category: category,
            paidBy: paidBy,
            shares: shares
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