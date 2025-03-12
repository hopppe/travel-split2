//
//  TabControlView.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// Tab Control View
struct TabControlView: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "Expenses", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            
            TabButton(title: "Balances", isSelected: selectedTab == 1) {
                selectedTab = 1
            }
            
            TabButton(title: "Participants", isSelected: selectedTab == 2) {
                selectedTab = 2
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}

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

// Trip Actions Menu
struct TripActionsMenu: View {
    let onAddExpense: () -> Void
    let onAddParticipant: () -> Void
    let onShareTrip: () -> Void
    let onChangeCurrency: () -> Void
    let onDeleteTrip: () -> Void
    
    var body: some View {
        Menu {
            // Add expense action
            Button(action: onAddExpense) {
                Label("Add Expense", systemImage: "dollarsign.circle")
            }
            
            // Add participant action
            Button(action: onAddParticipant) {
                Label("Add Participant", systemImage: "person.badge.plus")
            }
            
            // Share trip action
            Button(action: onShareTrip) {
                Label("Share Trip", systemImage: "square.and.arrow.up")
            }
            
            // Change currency action
            Button(action: onChangeCurrency) {
                Label("Change Currency", systemImage: "dollarsign.circle.fill")
            }
            
            Divider()
            
            // Delete trip action
            Button(role: .destructive, action: onDeleteTrip) {
                Label("Delete Trip", systemImage: "trash.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }
} 