//
//  ParticipantClaimView.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// MARK: - Participant Claim View

/// A view that allows users to claim an existing participant when joining a trip
struct ParticipantClaimView: View {
    @ObservedObject var viewModel: TripViewModel
    let potentialMatches: [User]
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header content
                Text("We found existing participants that might be you")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)
                    .accessibilityAddTraits(.isHeader)
                
                Text("A participant with similar name or email was found in this trip. Do you want to claim this participant as your account?")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // Match list and options
                List {
                    // Potential matches section
                    Section(header: Text("Select a participant to claim")) {
                        ForEach(potentialMatches) { participant in
                            Button(action: {
                                viewModel.claimParticipant(participant, inTrip: trip)
                                dismiss()
                            }) {
                                ParticipantMatchRow(participant: participant)
                            }
                            .accessibilityHint("Claim this participant as your account")
                        }
                    }
                    
                    // Join as new section
                    Section {
                        Button(action: {
                            viewModel.addCurrentUserToTrip(trip)
                            dismiss()
                        }) {
                            HStack {
                                Text("Join as a new participant")
                                    .fontWeight(.medium)
                                
                                Spacer()
                                
                                Image(systemName: "person.badge.plus")
                            }
                            .foregroundColor(.blue)
                        }
                        .accessibilityHint("Join the trip as a new participant")
                    } footer: {
                        Text("If none of these participants are you, join as a new participant instead.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

/// Row displaying a potential participant match
struct ParticipantMatchRow: View {
    let participant: User
    
    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.indigo.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(participant.name.prefix(1)))
                        .foregroundColor(.indigo)
                )
                .accessibilityHidden(true)
            
            // Participant details
            VStack(alignment: .leading, spacing: 4) {
                Text(participant.name)
                    .font(.headline)
                
                if !participant.email.isEmpty {
                    Text(participant.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Claim button
            Text("Claim")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Claim \(participant.name)\(participant.email.isEmpty ? "" : ", email: \(participant.email)")")
    }
}

// MARK: - Preview

#Preview {
    let viewModel = TripViewModel(currentUser: User.create(name: "Preview User", email: "preview@example.com"))
    let trip = Trip.create(name: "Sample Trip", description: "Preview trip", creator: viewModel.currentUser)
    let potentialMatches = [
        User.createUnclaimed(name: "John", email: "john@example.com"),
        User.createUnclaimed(name: "Preview User")
    ]
    
    return ParticipantClaimView(viewModel: viewModel, potentialMatches: potentialMatches, trip: trip)
} 