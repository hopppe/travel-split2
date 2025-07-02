//
//  ParticipantClaimView.swift
//  EquiSplit
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
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header section
                VStack(spacing: 16) {
                    Text("found_existing_participants".localized)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                    
                    Text("claim_participant_description".localized)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Participants list
                if !potentialMatches.isEmpty {
                    VStack(spacing: 16) {
                        VStack(alignment: languageAwareHorizontalAlignment, spacing: 12) {
                            Text("select_participant_to_claim".localized)
                                .font(.headline)
                                .padding(.horizontal)
                                .rtlAwareAlignment()
                            
                            LazyVStack(spacing: 8) {
                                ForEach(potentialMatches, id: \.id) { participant in
                                    Button {
                                        claimParticipant(participant)
                                    } label: {
                                        ParticipantMatchRow(participant: participant)
                                            .padding(.horizontal)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        
                        // Join as new participant button
                        VStack(spacing: 12) {
                            Button("join_as_new_participant".localized) {
                                joinAsNewParticipant()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            
                            Text("claim_participant_footer".localized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("join_group_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func claimParticipant(_ participant: User) {
        viewModel.claimParticipant(participant)
        dismiss()
    }
    
    private func joinAsNewParticipant() {
        viewModel.joinTrip(withInviteCode: trip.inviteCode) { success in
            if success {
                dismiss()
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
            VStack(alignment: languageAwareHorizontalAlignment, spacing: 4) {
                Text(participant.name)
                    .font(.headline)
                    .rtlAwareAlignment()
                
                if !participant.email.isEmpty {
                    Text(participant.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment()
                }
            }
            
            Spacer()
            
            // Claim button
            Text("claim".localized)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("claim".localized + " \(participant.name)\(participant.email.isEmpty ? "" : ", email: \(participant.email)")")
    }
}

// MARK: - Preview

#Preview {
    ParticipantClaimView(
        viewModel: TripViewModel(currentUser: User(id: "preview-user", name: "Preview User", email: "preview@example.com")),
        potentialMatches: [
            User(id: "1", name: "John Doe", email: "john@example.com"),
            User(id: "2", name: "Jane Smith", email: "jane@example.com")
        ],
        trip: Trip(
            id: "trip1",
            name: "Sample Trip",
            description: "A sample trip for preview",
            startDate: nil,
            endDate: nil,
            participants: [],
            expenses: [],
            inviteCode: "ABC123",
            baseCurrencyCode: "USD"
        )
    )
} 