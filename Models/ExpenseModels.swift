import Foundation

// MARK: - Expense Participant Amount
/// Represents how much a participant owes for an expense
struct ParticipantAmount: Identifiable, Codable {
    var id: String { participantId }
    var participantId: String
    var amount: Double
}

// MARK: - Expense Model Extensions
/// For use in the AddExpenseSheet and EditExpenseSheet
extension Expense {
    // Constructor from form data
    init(id: String, tripId: String, name: String, amount: Double, date: Date, payerId: String, currencySymbol: String, participantAmounts: [ParticipantAmount]) {
        self.id = id
        self.title = name
        self.description = ""
        self.amount = amount
        self.date = date
        self.category = .other
        self.paidBy = User(id: payerId, name: "", email: "", profileImage: nil) // This will be filled in by the view model
        self.shares = [] // This will be created by the view model from participantAmounts
    }
    
    // Properties used by expense sheets
    var name: String { title }
    var payerId: String { paidBy.id } 
    var currencySymbol: String { "$" } // Default - in a real app this would be stored
    
    // Convert between ParticipantAmount and ExpenseShare
    var participantAmounts: [ParticipantAmount] {
        shares.map { share in
            ParticipantAmount(participantId: share.user.id, amount: share.amount)
        }
    }
} 