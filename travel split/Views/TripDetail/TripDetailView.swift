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
    @State private var selectedExpense: Expense?
    @State private var selectedTab = 0
    
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
                    onShareTrip: shareTrip
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
    }
    
    // Share trip function with improved context
    private func shareTrip() {
        let shareLink = viewModel.generateShareLink()
        
        // Create a more detailed share message
        let shareMessage = """
        Join my trip '\(trip.name)' in Travel Split!
        
        • \(trip.participants.count) participants
        • \(trip.expenses.count) expenses
        • Total: \(formatCurrency(trip.expenses.reduce(0) { $0 + $1.amount }))
        
        Use this link to join and view details:
        """
        
        let activityVC = UIActivityViewController(
            activityItems: [
                shareMessage,
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
    
    // Helper to format currency
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$" // Default to USD
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
} 