//
//  TripDetailView.swift
//  EquiSplit
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
    
    // Language manager for localization updates
    @EnvironmentObject var languageManager: LanguageManager
    
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
            
            // Set up observer for deep link navigation to expenses
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("NavigateToExpenses"),
                object: nil,
                queue: .main
            ) { _ in
                // Ensure we're on the expenses tab when navigated via deep link
                if self.trip.id == self.viewModel.currentTrip?.id {
                    self.selectedTab = 0 // Expenses tab
                    print("Switched to expenses tab for deep link navigation")
                }
            }
        }
        .onDisappear {
            // Clean up notification observer
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name("NavigateToExpenses"), object: nil)
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
                .environmentObject(languageManager)
            }
        }
        .sheet(isPresented: $showingAddExpenseSheet) {
            NavigationStack {
                AddExpenseSheet(viewModel: viewModel)
                    .environmentObject(languageManager)
            }
        }
        .sheet(isPresented: $showingAddParticipantSheet) {
            AddParticipantSheet(viewModel: viewModel)
                .environmentObject(languageManager)
        }
        .sheet(item: $selectedExpense) { expense in
            NavigationStack {
                EditExpenseSheet(viewModel: viewModel, expense: expense)
                    .environmentObject(languageManager)
            }
        }
        .sheet(isPresented: $showingCurrencyPicker) {
            CurrencyCodePickerSheet(viewModel: viewModel, isPresented: $showingCurrencyPicker)
                .environmentObject(languageManager)
        }
        .confirmationDialog(
            "leave_group".localized,
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("leave_group".localized, role: .destructive) {
                leaveTrip()
            }
            
            Button("cancel".localized, role: .cancel) {
                // Do nothing
            }
        } message: {
            if viewModel.isLastParticipantInTrip(trip) {
                Text("leave_group_last_participant".localized)
            } else {
                Text("leave_group_confirmation".localized)
            }
        }
        .alert("cannot_leave_group".localized, isPresented: $showingBalanceWarning) {
            Button("ok".localized, role: .cancel) {}
        } message: {
            Text("outstanding_balance_message".localized(with: viewModel.getUserBalanceString(trip)))
        }
    }
    
    // Share trip function with improved context
    private func shareTrip() {
        // Use the centralized share message generation
        let shareMessage = FirebaseService.shared.generateShareMessage(
            inviteCode: trip.inviteCode,
            tripName: trip.name
        )
        
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