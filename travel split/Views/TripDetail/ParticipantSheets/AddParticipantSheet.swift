//
//  AddParticipantSheet.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI
import Foundation

// Local struct for participant entry
struct AddParticipantEntry: Identifiable {
    var id = UUID()
    var name: String = ""
    var email: String = ""
}

// Local view for displaying a previous participant
struct AddPreviousParticipantView: View {
    let participant: User
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack(alignment: .bottomTrailing) {
                    // Avatar circle
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(participant.name.prefix(1).uppercased())
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        )
                    
                    // Selection indicator
                    if isSelected {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Image(systemName: "checkmark")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                            .offset(x: 5, y: 5)
                    }
                }
                
                Text(participant.name)
                    .font(.caption)
                    .lineLimit(1)
                    .multilineTextAlignment(.center)
                    .frame(width: 60)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(participant.name)\(isSelected ? ", selected" : "")")
        .accessibilityHint(isSelected ? "Double tap to remove" : "Double tap to add")
    }
}

struct AddParticipantSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var participants: [AddParticipantEntry] = [AddParticipantEntry()]
    @State private var previousParticipants: [User] = []
    @State private var selectedPreviousParticipants = Set<String>()
    
    var body: some View {
        NavigationStack {
            Form {
                // Previous participants suggestions
                if !previousParticipants.isEmpty {
                    Section(header: Text("Previous Participants")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(previousParticipants) { participant in
                                    AddPreviousParticipantView(
                                        participant: participant,
                                        isSelected: selectedPreviousParticipants.contains(participant.id),
                                        onTap: {
                                            toggleParticipantSelection(participant)
                                        }
                                    )
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, -16) // Extend beyond section edges
                    }
                }
                
                Section(header: Text("Add Participants")) {
                    ForEach(0..<participants.count, id: \.self) { index in
                        VStack(spacing: 12) {
                            TextField("Name", text: $participants[index].name)
                                .padding(.vertical, 4)
                        }
                        .padding(.bottom, 8)
                        .overlay(
                            // Only add bottom border if not the last item
                            Group {
                                if index < participants.count - 1 {
                                    Rectangle()
                                        .frame(height: 0.5)
                                        .foregroundColor(Color.gray.opacity(0.3))
                                        .offset(y: 12)
                                }
                            }
                            , alignment: .bottom
                        )
                    }
                    
                    Button(action: {
                        participants.append(AddParticipantEntry())
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.accentColor)
                            Text("Add More")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Add Participants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveParticipants()
                    }
                    .disabled(!isFormValid)
                }
            }
            .onAppear {
                // Load previous participants when the view appears
                previousParticipants = viewModel.getPreviousParticipants()
            }
        }
    }
    
    // Form validation
    private var isFormValid: Bool {
        // Valid if either:
        // 1. There's at least one manually added participant with a non-empty name, OR
        // 2. There's at least one selected previous participant
        let hasValidManualParticipants = !participants.isEmpty && participants.allSatisfy { !$0.name.isEmpty }
        let hasSelectedPreviousParticipants = !selectedPreviousParticipants.isEmpty
        
        return hasValidManualParticipants || hasSelectedPreviousParticipants
    }
    
    // Toggle the selection of a previous participant
    private func toggleParticipantSelection(_ participant: User) {
        if selectedPreviousParticipants.contains(participant.id) {
            selectedPreviousParticipants.remove(participant.id)
        } else {
            selectedPreviousParticipants.insert(participant.id)
        }
    }
    
    // Save the participants
    private func saveParticipants() {
        // Filter out empty entries
        let validParticipants = participants.filter { !$0.name.isEmpty }
        
        // Add manually entered participants
        for entry in validParticipants {
            let newParticipant = User.createUnclaimed(
                name: entry.name,
                email: ""
            )
            
            // Call the method on the view model
            viewModel.addParticipantToCurrentTrip(newParticipant)
        }
        
        // Add selected previous participants
        for participantId in selectedPreviousParticipants {
            if let participant = previousParticipants.first(where: { $0.id == participantId }) {
                viewModel.addParticipantToCurrentTrip(participant)
            }
        }
        
        // Dismiss the sheet
        dismiss()
    }
}

// Preview provider
struct AddParticipantSheet_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TripViewModel(currentUser: User.create(name: "Test User", email: "test@example.com"))
        return AddParticipantSheet(viewModel: viewModel)
    }
} 