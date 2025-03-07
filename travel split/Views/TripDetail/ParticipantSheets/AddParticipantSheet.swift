//
//  AddParticipantSheet.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

struct AddParticipantSheet: View {
    @ObservedObject var viewModel: TripViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var participants: [ParticipantEntry] = [ParticipantEntry()]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Add Participants")) {
                    ForEach(0..<participants.count, id: \.self) { index in
                        VStack(spacing: 12) {
                            TextField("Name", text: $participants[index].name)
                                .padding(.vertical, 4)
                            
                            TextField("Email (optional)", text: $participants[index].email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .padding(.vertical, 4)
                            
                            if participants.count > 1 && index < participants.count - 1 {
                                Divider()
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    
                    Button(action: {
                        participants.append(ParticipantEntry())
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
        }
    }
    
    // Form validation
    private var isFormValid: Bool {
        !participants.isEmpty && participants.allSatisfy { !$0.name.isEmpty }
    }
    
    // Save the participants
    private func saveParticipants() {
        // Filter out empty entries
        let validParticipants = participants.filter { !$0.name.isEmpty }
        
        // Add each participant
        for entry in validParticipants {
            let newParticipant = User.createUnclaimed(
                name: entry.name,
                email: entry.email
            )
            
            // Call the method on the view model
            viewModel.addParticipantToCurrentTrip(newParticipant)
        }
        
        // Dismiss the sheet
        dismiss()
    }
}

// Helper struct for participant entry
struct ParticipantEntry {
    var name: String = ""
    var email: String = ""
}

// Preview provider
struct AddParticipantSheet_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = TripViewModel(currentUser: User.create(name: "Test User", email: "test@example.com"))
        return AddParticipantSheet(viewModel: viewModel)
    }
} 