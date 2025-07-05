//
//  BalancesViews.swift
//  EquiSplit
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import TravelSplitModels
import TravelSplitServices
import TravelSplitViewModels
import TravelSplitExtensions

// MARK: - Main Balance View

/// Main view for the trip balances tab showing debts and settlements
struct BalancesView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if let trip = viewModel.currentTrip, !trip.expenses.isEmpty {
                let debts = viewModel.calculateDebts()
                
                if debts.isEmpty {
                    SettledUpView()
                        .environmentObject(viewModel)
                } else {
                    BalancesContentView(trip: trip, debts: debts, viewModel: viewModel)
                }
            } else {
                NoExpensesView()
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: - Currency Picker Sheet

/// Sheet for selecting the base currency
struct CurrencyCodePickerSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    @State private var selectedCurrencyCode: String
    
    init(viewModel: TripViewModel, isPresented: Binding<Bool>) {
        self.viewModel = viewModel
        self._isPresented = isPresented
        self._selectedCurrencyCode = State(initialValue: viewModel.getBaseCurrencyCode())
    }
    
    var body: some View {
        CurrencyCodePickerView(
            currencyCode: $selectedCurrencyCode,
            isPresented: $isPresented,
            onCurrencySelected: { code in
                viewModel.updateBaseCurrency(to: code)
            }
        )
    }
}

// MARK: - State Views

/// View shown when all participants are settled (no debts)
struct SettledUpView: View {
    @State private var showingRecordPaymentSheet = false
    @EnvironmentObject var viewModel: TripViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)
                .accessibilityHidden(true)
            
            Text("all_settled_up".localized)
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text("everyone_paid_fair_share".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
            
            // Record Payment Button
            Button(action: {
                showingRecordPaymentSheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("record_a_payment".localized)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .accessibilityLabel("record_a_payment".localized)
        }
        .padding()
#if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\("all_settled_up".localized). \("everyone_paid_fair_share".localized).")
#endif
        .sheet(isPresented: $showingRecordPaymentSheet) {
            NavigationStack {
                RecordPaymentSheet(viewModel: viewModel)
            }
        }
    }
}

/// View shown when there are no expenses to calculate balances
struct NoExpensesView: View {
    @State private var showingRecordPaymentSheet = false
    @EnvironmentObject var viewModel: TripViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.accentColor.opacity(0.5))
                .accessibilityHidden(true)
            
            Text("no_expenses_to_calculate".localized)
                .font(.title3)
                .fontWeight(.semibold)
                .accessibilityAddTraits(.isHeader)
            
            Text("add_expenses_to_see_debts".localized)
                .font(.body)
                .foregroundColor(.secondary)
                .padding(.bottom, 30)
            
            // Record Payment Button
            Button(action: {
                showingRecordPaymentSheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("record_a_payment".localized)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal, 40)
            .accessibilityLabel("record_a_payment".localized)
        }
        .padding()
#if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\("no_expenses_to_calculate".localized). \("add_expenses_to_see_debts".localized).")
#endif
        .sheet(isPresented: $showingRecordPaymentSheet) {
            NavigationStack {
                RecordPaymentSheet(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Balance Content View

/// Main content view displaying balances and debts
struct BalancesContentView: View {
    let trip: Trip
    let debts: [Debt]
    @ObservedObject var viewModel: TripViewModel
    @State private var showingRecordPaymentSheet = false
    
    var body: some View {
        VStack {
            List {
                // User balance overview section
                Section(header: Text("your_balance".localized)) {
                    if let currentUserInTrip = viewModel.findCurrentUserInTrip() {
                        UserBalanceRow(
                            user: currentUserInTrip,
                            balance: calculateUserBalance(for: currentUserInTrip.id),
                            isCurrentUser: true,
                            currencySymbol: trip.baseCurrencySymbol,
                            viewModel: viewModel
                        )
                    } else {
                        UserBalanceRow(
                            user: viewModel.currentUser,
                            balance: calculateUserBalance(for: viewModel.currentUser.id),
                            isCurrentUser: true,
                            currencySymbol: trip.baseCurrencySymbol,
                            viewModel: viewModel
                        )
                    }
                }
                
                // Debts section
                Section(header: Text("who_owes_what".localized)) {
                    // First show actual debts
                    ForEach(debts, id: \.id) { debt in
                        DebtRowView(
                            debt: debt,
                            currencySymbol: trip.baseCurrencySymbol,
                            viewModel: viewModel
                        )
                    }
                    
                    // Then show participants with zero balance
                    if let currentUserInTrip = viewModel.findCurrentUserInTrip() {
                        // Get all participants who don't appear in any debt
                        let participantsInDebts = Set(debts.map { $0.from.id } + debts.map { $0.to.id })
                        let settledParticipants = trip.participants.filter { participant in
                            // Don't show current user in this list (they appear in "Your Balance" section)
                            participant.id != currentUserInTrip.id && 
                            !participantsInDebts.contains(participant.id)
                        }
                        
                        // Display participants with zero balance
                        ForEach(settledParticipants, id: \.id) { participant in
                            SettledDebtRowView(
                                participant: participant,
                                currencySymbol: trip.baseCurrencySymbol
                            )
                        }
                    }
                }
                
                // Summary section
                Section(header: Text("summary".localized)) {
                    TotalSummaryView(trip: trip, currencySymbol: trip.baseCurrencySymbol)
                }
                
                // Info section
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("all_amounts_shown_in".localized(with: trip.baseCurrencyCode))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            
            // Record Payment Button
            Button(action: {
                showingRecordPaymentSheet = true
            }) {
                HStack {
                    Image(systemName: "arrow.left.arrow.right.circle.fill")
                    Text("record_a_payment".localized)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .accessibilityLabel("record_a_payment".localized)
            .sheet(isPresented: $showingRecordPaymentSheet) {
                NavigationStack {
                    RecordPaymentSheet(viewModel: viewModel)
                }
            }
        }
    }
    
    /// Calculate the total balance for a specific user
    private func calculateUserBalance(for userId: String) -> Double {
        var balance: Double = 0
        
        // Add money owed to the user
        for debt in debts where debt.to.id == userId {
            balance += debt.amount
        }
        
        // Subtract money owed by the user
        for debt in debts where debt.from.id == userId {
            balance -= debt.amount
        }
        
        return balance
    }
}

// MARK: - Row Views

/// Row displaying a user's balance
struct UserBalanceRow: View {
    let user: User
    let balance: Double
    let isCurrentUser: Bool
    let currencySymbol: String
    @ObservedObject var viewModel: TripViewModel
    @State private var showBreakdown = false
    
    var body: some View {
        HStack {
            // Profile image or initial
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(String(user.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: languageAwareHorizontalAlignment, spacing: 4) {
                Text(isCurrentUser ? "you".localized : user.name)
                    .font(.headline)
                    .rtlAwareAlignment()
                
                Text(balanceDescription)
                    .font(.subheadline)
                    .foregroundColor(balanceColor)
                    .rtlAwareAlignment()
            }
            
            Spacer()
            
            Text(formattedBalance)
                .font(.headline)
                .foregroundColor(balanceColor)
        }
        .padding(.vertical, 4)
#if !SKIP
        .contentShape(Rectangle()) // Make entire row tappable
#endif
        .onTapGesture {
            // Get the first user debt if there is one, otherwise don't show the sheet
            if getFirstUserDebt() != nil {
                showBreakdown = true
            }
        }
#if !SKIP
        .accessibilityElement(children: .combine)
#endif
        .accessibilityLabel("\(isCurrentUser ? "you".localized : user.name) \(balanceDescription) \(formattedBalance)")
        .accessibilityHint("tap_to_see_breakdown".localized)
        .sheet(isPresented: $showBreakdown) {
            if let debt = getFirstUserDebt() {
                NavigationStack {
                    BalanceBreakdownSheet(
                        viewModel: viewModel,
                        isPresented: $showBreakdown,
                        debt: debt
                    )
                }
                .presentationDetents([.large])
            }
        }
    }
    
    /// Description of the balance (owes, receives, settled)
    private var balanceDescription: String {
        if balance > 0 {
            return "will_receive".localized
        } else if balance < 0 {
            return "owes_others".localized
        } else {
            return "is_settled_up".localized
        }
    }
    
    /// Color based on balance status
    private var balanceColor: Color {
        if balance > 0 {
            return .green
        } else if balance < 0 {
            return .red
        } else {
            return .secondary
        }
    }
    
    /// Formatted currency amount
    private var formattedBalance: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: abs(balance))) ?? "\(currencySymbol)0.00"
    }
    
    /// Get the first debt related to this user
    private func getFirstUserDebt() -> Debt? {
        let debts = viewModel.calculateDebts()
        
        // First try to find a debt involving this user
        if let debt = debts.first(where: { $0.from.id == user.id || $0.to.id == user.id }) {
            return debt
        }
        
        // If no debt found but user has a non-zero balance, create a synthetic debt
        // representing their balance with another participant
        if balance != 0, let trip = viewModel.currentTrip, trip.participants.count > 1 {
            // Find another participant to represent the debt with
            if let otherParticipant = trip.participants.first(where: { $0.id != user.id }) {
                if balance < 0 {
                    // User owes money to someone else
                    return Debt(
                        from: user,
                        to: otherParticipant,
                        amount: abs(balance)
                    )
                } else {
                    // User is owed money by someone else
                    return Debt(
                        from: otherParticipant,
                        to: user,
                        amount: abs(balance)
                    )
                }
            }
        }
        
        return nil
    }
}

/// Row displaying a debt between two users
struct DebtRowView: View {
    let debt: Debt
    let currencySymbol: String
    @ObservedObject var viewModel: TripViewModel
    @State private var showBreakdown = false
    
    var body: some View {
        HStack {
            VStack(alignment: languageAwareHorizontalAlignment, spacing: 4) {
                Text(debt.from.name)
                    .font(.headline)
                    .rtlAwareAlignment()
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .accessibilityHidden(true)
                    
                    Text("owes".localized)
                        .font(.caption)
                        .rtlAwareAlignment()
                    
                    Text(debt.to.name)
                        .font(.caption.bold())
                        .rtlAwareAlignment()
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(formattedAmount)
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
#if !SKIP
        .contentShape(Rectangle()) // Make entire row tappable
#endif
        .onTapGesture {
            showBreakdown = true
        }
#if !SKIP
        .accessibilityElement(children: .combine)
#endif
        .accessibilityLabel("\(debt.from.name) \("owes".localized) \(debt.to.name) \(formattedAmount)")
        .accessibilityHint("tap_to_see_debt_breakdown".localized)
        .sheet(isPresented: $showBreakdown) {
            NavigationStack {
                BalanceBreakdownSheet(
                    viewModel: viewModel,
                    isPresented: $showBreakdown,
                    debt: debt
                )
            }
            .presentationDetents([.large])
        }
    }
    
    /// Formatted currency amount
    private var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: debt.amount)) ?? "\(currencySymbol)\(debt.amount)"
    }
}

/// Row displaying a participant with no debts (zero balance)
struct SettledDebtRowView: View {
    let participant: User
    let currencySymbol: String
    
    var body: some View {
        HStack {
            VStack(alignment: languageAwareHorizontalAlignment, spacing: 4) {
                Text(participant.name)
                    .font(.headline)
                    .rtlAwareAlignment()
                
                Text("all_settled_up_lowercase".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .rtlAwareAlignment()
            }
            
            Spacer()
            
            Text("\(currencySymbol)0.00")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
#if !SKIP
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
#endif
        .accessibilityLabel("\(participant.name) \("is_settled_up".localized), zero balance")
    }
}

/// Summary view showing trip totals
struct TotalSummaryView: View {
    let trip: Trip
    let currencySymbol: String
    
    var body: some View {
        VStack(alignment: languageAwareHorizontalAlignment, spacing: 12) {
            HStack {
                Text("total_trip_cost".localized)
                    .font(.headline)
                    .rtlAwareAlignment()
                Spacer()
                Text(formattedTotalCost)
                    .font(.headline)
                    .rtlAwareAlignment()
            }
            
            HStack {
                Text("average_per_person".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .rtlAwareAlignment()
                Spacer()
                Text(formattedAveragePerPerson)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .rtlAwareAlignment()
            }
        }
        .padding(.vertical, 4)
#if !SKIP
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\("total_trip_cost".localized): \(formattedTotalCost), \("average_per_person".localized): \(formattedAveragePerPerson)")
#endif
    }
    
    // MARK: - Helper Properties and Methods
    
    /// Formatted total trip cost
    private var formattedTotalCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: totalTripCost())) ?? "\(currencySymbol)\(totalTripCost())"
    }
    
    /// Formatted average cost per person
    private var formattedAveragePerPerson: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = currencySymbol
        return formatter.string(from: NSNumber(value: averagePerPerson())) ?? "\(currencySymbol)\(averagePerPerson())"
    }
    
    /// Calculate total trip cost (all converted to base currency)
    private func totalTripCost() -> Double {
        trip.expenses.reduce(0) { total, expense in
            // Skip payment expenses (where one person paid and only one person has a share)
            if expense.shares.count == 1 && expense.shares[0].user.id == expense.paidBy.id {
                return total // Skip this expense as it's likely a payment
            }
            
            // Skip explicit payment expenses (where one person paid and only one other person has a share)
            if expense.shares.count == 1 && expense.shares[0].user.id != expense.paidBy.id && expense.description == "Payment" {
                return total // Skip this expense as it's a payment
            }
            
            let expenseCurrency = expense.currencyCode ?? "USD"
            let convertedAmount = CurrencyConverterService.shared.convert(
                amount: expense.amount,
                from: expenseCurrency,
                to: trip.baseCurrencyCode
            )
            return total + convertedAmount
        }
    }
    
    /// Calculate average cost per person
    private func averagePerPerson() -> Double {
        let total = totalTripCost()
        let count = trip.participants.count
        return count > 0 ? total / Double(count) : 0
    }
}

// MARK: - Preview Provider
struct BalancesView_Previews: PreviewProvider {
    static var previews: some View {
        // Create mock data
        let user = User(id: "1", name: "John", email: "john@example.com", isClaimed: true, claimedByUserId: "1")
        let user2 = User(id: "2", name: "Alice", email: "alice@example.com", isClaimed: true, claimedByUserId: "2")
        let expense1 = Expense.createEqual(
            title: "Dinner", 
            amount: 100.0, 
            paidBy: user, 
            participants: [user, user2],
            currencyCode: "USD"
        )
        let expense2 = Expense.createEqual(
            title: "Taxi", 
            amount: 50.0, 
            paidBy: user2, 
            participants: [user, user2],
            currencyCode: "EUR"
        )
        let trip = Trip(
            id: "1",
            name: "Weekend Trip",
            description: "A fun weekend",
            startDate: nil,
            endDate: nil,
            participants: [user, user2],
            expenses: [expense1, expense2],
            inviteCode: "12345678",
            baseCurrencyCode: "USD"
        )
        
        // Create view model with mock data
        let viewModel = TripViewModel(currentUser: user)
        viewModel.trips = [trip]
        viewModel.currentTrip = trip
        
        return NavigationView {
            BalancesView(viewModel: viewModel)
        }
    }
} 