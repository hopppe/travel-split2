import SwiftUI

struct TripDetailView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    @State private var showingAddExpenseSheet = false
    @State private var showingAddParticipantSheet = false
    @State private var selectedTab = 0
    @State private var showingDeleteConfirmation = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented control
            HStack(spacing: 0) {
                TabButton(title: "Expenses", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: "Balances", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Tab view content
            TabView(selection: $selectedTab) {
                // Expenses tab
                ExpensesListView(viewModel: viewModel, trip: trip)
                    .tag(0)
                
                // Balances tab
                BalancesView(viewModel: viewModel)
                    .tag(1)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: selectedTab)
        }
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.selectTrip(trip)
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    // Add expense action
                    Button(action: {
                        showingAddExpenseSheet = true
                    }) {
                        Label("Add Expense", systemImage: "dollarsign.circle")
                    }
                    
                    // Add participant action
                    Button(action: {
                        showingAddParticipantSheet = true
                    }) {
                        Label("Add Participant", systemImage: "person.badge.plus")
                    }
                    
                    // Share trip action
                    Button(action: {
                        shareTrip()
                    }) {
                        Label("Share Trip", systemImage: "square.and.arrow.up")
                    }
                    
                    Divider()
                    
                    // Delete trip action
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        Label("Delete Trip", systemImage: "trash.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            AddExpenseSheet(viewModel: viewModel, isPresented: $showingAddExpenseSheet)
        }
        .sheet(isPresented: $showingAddParticipantSheet) {
            AddParticipantSheet(viewModel: viewModel, isPresented: $showingAddParticipantSheet)
        }
        .confirmationDialog(
            "Delete Trip",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete for Everyone", role: .destructive) {
                deleteTrip()
            }
            
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: {
            Text("This will permanently delete the trip for all participants.")
        }
    }
    
    // Share trip function
    private func shareTrip() {
        let shareLink = viewModel.generateShareLink()
        let activityVC = UIActivityViewController(
            activityItems: [
                "Join my trip '\(trip.name)' in Travel Split!",
                shareLink
            ],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    private func deleteTrip() {
        viewModel.deleteTrip(withId: trip.id)
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - Supporting Views

// Tab Button View
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .fontWeight(isSelected ? .bold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                
                // Indicator bar
                Rectangle()
                    .frame(height: 3)
                    .cornerRadius(1.5)
                    .foregroundColor(isSelected ? .accentColor : .clear)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 8)
    }
}

// Expenses Tab View
struct ExpensesListView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    @State private var showingAddExpenseSheet = false
    @State private var isEditMode: EditMode = .inactive
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if trip.expenses.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("No Expenses Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add your first expense to start tracking")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showingAddExpenseSheet = true
                    }) {
                        Label("Add Expense", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                }
                .padding()
            } else {
                // Expenses list
                List {
                    ForEach(groupedExpenses.keys.sorted(by: >), id: \.self) { date in
                        Section(header: Text(formatDate(date))) {
                            ForEach(groupedExpenses[date] ?? []) { expense in
                                NavigationLink {
                                    EditExpenseSheet(viewModel: viewModel, expense: expense)
                                } label: {
                                    ExpenseRowView(expense: expense)
                                }
                                .swipeActions(edge: .trailing) {
                                    Button("Delete", role: .destructive) {
                                        viewModel.deleteExpense(withId: expense.id)
                                    }
                                }
                                .contextMenu {
                                    Button("Edit", action: {
                                        // Navigation handled automatically by NavigationLink
                                    }) {
                                        Label("Edit Expense", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        viewModel.deleteExpense(withId: expense.id)
                                    }) {
                                        Label("Delete Expense", systemImage: "trash")
                                    }
                                }
                            }
                            .onDelete { indexSet in
                                let expensesToDelete = indexSet.map { groupedExpenses[date]![$0] }
                                for expense in expensesToDelete {
                                    viewModel.deleteExpense(withId: expense.id)
                                }
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, $isEditMode)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        if !trip.expenses.isEmpty {
                            EditButton()
                        }
                    }
                }
                
                // Floating action button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingAddExpenseSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            AddExpenseSheet(viewModel: viewModel, isPresented: $showingAddExpenseSheet)
        }
    }
    
    // Group expenses by date
    private var groupedExpenses: [Date: [Expense]] {
        let calendar = Calendar.current
        var result: [Date: [Expense]] = [:]
        
        for expense in trip.expenses {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: expense.date)
            if let date = calendar.date(from: dateComponents) {
                var expenses = result[date] ?? []
                expenses.append(expense)
                result[date] = expenses
            }
        }
        
        return result
    }
    
    // Format date for section headers
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

// Expense Row View
struct ExpenseRowView: View {
    let expense: Expense
    
    var body: some View {
        HStack {
            // Category icon
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: expense.category.icon)
                    .font(.headline)
                    .foregroundColor(.accentColor)
            }
            
            // Expense details
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.title)
                    .font(.headline)
                
                HStack {
                    Text("Paid by \(expense.paidBy.name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if expense.shares.count > 1 {
                        Text("• Split \(expense.shares.count) ways")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // Amount
            Text("$\(expense.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// Balances View
struct BalancesView: View {
    @ObservedObject var viewModel: TripViewModel
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            if let trip = viewModel.currentTrip, !trip.expenses.isEmpty {
                let debts = viewModel.calculateDebts()
                
                if debts.isEmpty {
                    // All settled
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                        
                        Text("All Settled Up!")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Everyone has paid their fair share")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Show balances
                    List {
                        Section(header: Text("Who Owes What")) {
                            ForEach(debts, id: \.id) { debt in
                                DebtRowView(debt: debt)
                            }
                        }
                        
                        Section(header: Text("Summary"), footer: Text("These calculations help simplify payments between group members.")) {
                            TotalSummaryView(trip: trip)
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }
            } else {
                // No expenses yet
                VStack(spacing: 16) {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor.opacity(0.5))
                    
                    Text("No Expenses to Calculate")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Add expenses to see who owes what")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// Debt Row View
struct DebtRowView: View {
    let debt: Debt
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(debt.from.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "arrow.right")
                        .font(.caption)
                    Text("owes")
                        .font(.caption)
                    Text(debt.to.name)
                        .font(.caption.bold())
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("$\(debt.amount, specifier: "%.2f")")
                .font(.headline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

// Total Summary View
struct TotalSummaryView: View {
    let trip: Trip
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Total Trip Cost")
                    .font(.headline)
                Spacer()
                Text("$\(totalTripCost(), specifier: "%.2f")")
                    .font(.headline)
            }
            
            HStack {
                Text("Average Per Person")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("$\(averagePerPerson(), specifier: "%.2f")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    // Calculate total trip cost
    private func totalTripCost() -> Double {
        trip.expenses.reduce(0) { $0 + $1.amount }
    }
    
    // Calculate average per person
    private func averagePerPerson() -> Double {
        let total = totalTripCost()
        let count = trip.participants.count
        return count > 0 ? total / Double(count) : 0
    }
}

// Add Expense Sheet
struct AddExpenseSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    
    @State private var expenseTitle = ""
    @State private var expenseAmount = ""
    @State private var selectedCategory: ExpenseCategory = .food
    @State private var selectedPayer: User?
    @State private var splitType: SplitType = .equal
    @State private var customShares: [ExpenseShare] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic expense info
                Section(header: Text("Basic Info")) {
                    TextField("Title", text: $expenseTitle)
                    
                    HStack {
                        Text("$")
                        TextField("Amount", text: $expenseAmount)
                            .keyboardType(.decimalPad)
                    }
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ExpenseCategory.allCases) { category in
                            Label(category.rawValue, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                }
                
                // Payer selection
                if let trip = viewModel.currentTrip {
                    Section(header: Text("Paid By")) {
                        ForEach(trip.participants) { user in
                            Button(action: {
                                selectedPayer = user
                            }) {
                                HStack {
                                    Text(user.name)
                                    Spacer()
                                    if selectedPayer?.id == user.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.accentColor)
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    
                    // Split type
                    Section(header: Text("Split Type")) {
                        Picker("Split Type", selection: $splitType) {
                            Text("Equal").tag(SplitType.equal)
                            Text("Custom").tag(SplitType.custom)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        if splitType == .custom {
                            ForEach(trip.participants) { user in
                                HStack {
                                    Text(user.name)
                                    Spacer()
                                    if let amount = getAmount() {
                                        let share = getCustomShare(for: user)
                                        TextField("Amount", value: Binding(
                                            get: { share?.amount ?? amount / Double(trip.participants.count) },
                                            set: { updateCustomShare(for: user, amount: $0) }
                                        ), format: .currency(code: "USD"))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveExpense()
                    }
                    .disabled(!isFormValid())
                }
            }
            .onAppear {
                // Default to current user as payer
                selectedPayer = viewModel.currentUser
                
                // Initialize custom shares if current trip exists
                if let trip = viewModel.currentTrip {
                    initializeCustomShares(for: trip.participants)
                }
            }
        }
    }
    
    // Check if the form is valid
    private func isFormValid() -> Bool {
        guard !expenseTitle.isEmpty,
              let amount = Double(expenseAmount),
              amount > 0,
              selectedPayer != nil else {
            return false
        }
        
        if splitType == .custom {
            let totalAmount = customShares.reduce(0) { $0 + $1.amount }
            let expenseAmount = getAmount() ?? 0
            return abs(totalAmount - expenseAmount) < 0.01 // Allow for small floating point differences
        }
        
        return true
    }
    
    // Save the expense
    private func saveExpense() {
        guard let amount = getAmount(),
              let payer = selectedPayer else {
            return
        }
        
        viewModel.addExpenseToCurrentTrip(
            title: expenseTitle,
            amount: amount,
            paidBy: payer,
            splitType: splitType,
            customShares: splitType == .custom ? customShares : nil,
            category: selectedCategory
        )
        
        isPresented = false
    }
    
    // Get the entered amount as a Double
    private func getAmount() -> Double? {
        return Double(expenseAmount.replacingOccurrences(of: ",", with: "."))
    }
    
    // Initialize custom shares for all participants
    private func initializeCustomShares(for participants: [User]) {
        guard let amount = getAmount() else { return }
        let equalShare = amount / Double(participants.count)
        
        customShares = participants.map { user in
            ExpenseShare(
                user: user,
                amount: equalShare,
                percentage: 100.0 / Double(participants.count)
            )
        }
    }
    
    // Get custom share for a specific user
    private func getCustomShare(for user: User) -> ExpenseShare? {
        return customShares.first(where: { $0.user.id == user.id })
    }
    
    // Update custom share for a specific user
    private func updateCustomShare(for user: User, amount: Double) {
        if let index = customShares.firstIndex(where: { $0.user.id == user.id }) {
            var share = customShares[index]
            share.amount = amount
            
            // Recalculate percentage if total expense amount is available
            if let totalAmount = getAmount(), totalAmount > 0 {
                share.percentage = (amount / totalAmount) * 100
            }
            
            customShares[index] = share
        } else if let expenseAmount = getAmount() {
            // Create new share if it doesn't exist
            let percentage = expenseAmount > 0 ? (amount / expenseAmount) * 100 : 0
            let share = ExpenseShare(user: user, amount: amount, percentage: percentage)
            customShares.append(share)
        }
    }
}

// Add Participant Sheet
struct AddParticipantSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var email = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Participant Details")) {
                    TextField("Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
            }
            .navigationTitle("Add Participant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addParticipant()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func addParticipant() {
        let newUser = User.create(name: name, email: email)
        viewModel.addParticipantToCurrentTrip(newUser)
        isPresented = false
    }
} 