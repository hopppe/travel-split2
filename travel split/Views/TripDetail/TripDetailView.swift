//
//  TripDetailView.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

struct TripDetailView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    @State private var showingAddExpenseSheet = false
    @State private var showingAddParticipantSheet = false
    @State private var showingCurrencyPicker = false
    @State private var selectedExpense: Expense?
    @State private var selectedTab = 0
    @State private var showingDeleteConfirmation = false
    @State private var showingBalanceWarning = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom segmented control
            TabControlView(selectedTab: $selectedTab)
            
            // Tab view content
            TabView(selection: $selectedTab) {
                // Expenses tab
                ExpensesListView(viewModel: viewModel, trip: trip, onAddExpense: {
                    showingAddExpenseSheet = true
                }, onEditExpense: { expense in
                    selectedExpense = expense
                })
                .tag(0)
                
                // Balances tab
                BalancesView(viewModel: viewModel)
                .tag(1)
                
                // Participants tab
                ParticipantsView(viewModel: viewModel, trip: trip, onAddParticipant: {
                    showingAddParticipantSheet = true
                })
                .tag(2)
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
                TripActionsMenu(
                    onAddExpense: { showingAddExpenseSheet = true },
                    onAddParticipant: { showingAddParticipantSheet = true },
                    onShareTrip: shareTrip,
                    onChangeCurrency: { showingCurrencyPicker = true },
                    onDeleteTrip: { 
                        if viewModel.canLeaveTrip(trip) {
                            showingDeleteConfirmation = true
                        } else {
                            showingBalanceWarning = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            NavigationStack {
                AddExpenseSheet(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingAddParticipantSheet) {
            AddParticipantSheet(viewModel: viewModel)
        }
        .sheet(item: $selectedExpense) { expense in
            NavigationStack {
                EditExpenseSheet(viewModel: viewModel, expense: expense)
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyCodePickerSheet(viewModel: viewModel, isPresented: $showingCurrencyPicker)
        }
        .confirmationDialog(
            "Leave Group",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Leave Group", role: .destructive) {
                leaveTrip()
            }
            
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
        } message: {
            Text("You will be removed from this group but other participants will still have access.")
        }
        .alert("Cannot Leave Group", isPresented: $showingBalanceWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You have an outstanding balance of \(viewModel.getUserBalanceString(trip)). You must settle all debts before leaving the group.")
        }
    }
    
    // Share trip function with improved context
    private func shareTrip() {
        // Get the deep link URL from FirebaseService
        let deepLinkURL = FirebaseService.shared.createDeepLink(inviteCode: trip.inviteCode)
        
        // Create a simple share message with just the essentials
        let shareMessage = """
        Join my group '\(trip.name)' in Travel Split!
        
        Link: \(deepLinkURL)
        Code: \(trip.inviteCode)
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [shareMessage],
            applicationActivities: nil
        )
        
        // Present the share sheet
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
    
    // Helper to format currency
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = trip.baseCurrencySymbol
        return formatter.string(from: NSNumber(value: amount)) ?? "\(trip.baseCurrencySymbol)\(amount)"
    }
    
    // Delete trip function
    private func deleteTrip() {
        viewModel.deleteTrip(withId: trip.id)
        presentationMode.wrappedValue.dismiss()
    }
    
    // Leave trip function
    private func leaveTrip() {
        viewModel.leaveTrip(trip: trip)
        presentationMode.wrappedValue.dismiss()
    }
} 