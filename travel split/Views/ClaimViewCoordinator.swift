//
//  ClaimViewCoordinator.swift
//  travel split
//
//  Created by Assistant on 3/5/25.
//

import SwiftUI

struct ClaimViewCoordinator: View {
    @ObservedObject var viewModel: TripViewModel
    @Binding var showClaimSheet: Bool
    
    var body: some View {
        NavigationStack {
            VStack {
                if let trip = viewModel.currentTrip, !viewModel.potentialClaimableParticipants.isEmpty {
                    Text("Select a participant to join as")
                        .font(.headline)
                        .padding()
                    
                    List(viewModel.potentialClaimableParticipants) { participant in
                        Button(action: {
                            claimParticipant(participant)
                        }) {
                            HStack {
                                Circle()
                                    .fill(Color.indigo.opacity(0.2))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(String(participant.name.prefix(1)))
                                            .foregroundColor(.indigo)
                                    )
                                
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
                                
                                Text("Claim")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    
                    Button("Join as a new participant") {
                        joinAsNewParticipant()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding()
                } else {
                    Text("No participants to claim")
                        .font(.headline)
                        .padding()
                    
                    Button("Close") {
                        showClaimSheet = false
                    }
                    .buttonStyle(.bordered)
                }
            }
            .navigationTitle("Join Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cancelJoining()
                    }
                }
            }
            .onAppear {
                print("ClaimViewCoordinator appeared with \(viewModel.potentialClaimableParticipants.count) participants")
            }
        }
    }
    
    private func claimParticipant(_ participant: User) {
        // Directly call the view model's method to claim participant
        print("Claiming participant: \(participant.name)")
        viewModel.claimParticipant(participant)
        completeJoining()
    }
    
    private func joinAsNewParticipant() {
        print("Joining as new participant")
        if let trip = viewModel.currentTrip {
            viewModel.addCurrentUserToTrip(trip)
        }
        completeJoining()
    }
    
    // Handle completion of joining a trip - dismiss all sheets and navigate to expenses
    private func completeJoining() {
        // Make sure we have a current trip
        guard let trip = viewModel.currentTrip else {
            // Reset the view state
            viewModel.showParticipantClaimingView = false
            viewModel.potentialClaimableParticipants = []
            
            // Dismiss this view
            showClaimSheet = false
            return
        }
        
        // Set the current trip (even though it's already set, this ensures it remains selected)
        viewModel.selectTrip(trip)
        
        // Reset the view state
        viewModel.showParticipantClaimingView = false
        viewModel.potentialClaimableParticipants = []
        
        // Dismiss this view
        showClaimSheet = false
        
        // The navigation to expense screen happens automatically because:
        // 1. We've set the currentTrip in the viewModel
        // 2. The TripDetailView will show when a trip is selected, with expenses tab selected by default
    }
    
    // Handle cancellation of joining a trip
    private func cancelJoining() {
        // Reset the view state
        viewModel.showParticipantClaimingView = false
        viewModel.potentialClaimableParticipants = []
        
        // Dismiss this view
        showClaimSheet = false
    }
} 