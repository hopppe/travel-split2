//
//  ParticipantsViews.swift
//  travel split
//
//  Created by Ethan Hoppe on 3/5/25.
//

import SwiftUI

// MARK: - Participants View

/// Main view for displaying and managing trip participants
struct ParticipantsView: View {
    @ObservedObject var viewModel: TripViewModel
    let trip: Trip
    let onAddParticipant: () -> Void
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                List {
                    // People section
                    Section(header: Text("People on this trip")) {
                        ForEach(trip.participants) { participant in
                            ParticipantRowView(
                                participant: participant,
                                isCurrentUser: participant.id == viewModel.currentUser.id
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(buildAccessibilityLabel(for: participant))
                        }
                    }
                    
                    // Invite section - only shown if there are unclaimed participants
                    if hasUnclaimedParticipants {
                        Section {
                            Button(action: { showShareSheet = true }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.accentColor)
                                    Text("Invite People to Claim Placeholders")
                                        .foregroundColor(.primary)
                                }
                            }
                            .accessibilityHint("Share trip to let others claim placeholder participants")
                        } footer: { 
                            Text("You have \(unclaimedParticipantCount) unclaimed placeholder \(unclaimedParticipantCount == 1 ? "participant" : "participants"). Share the trip link so others can join and claim these participants.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Add participant section
                    Section {
                        Button(action: onAddParticipant) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.accentColor)
                                Text("Add Participant")
                                    .foregroundColor(.primary)
                            }
                        }
                        .accessibilityHint("Add a new participant to this trip")
                    } footer: {
                        Text("Tip: You can add placeholder participants that others can claim when they join.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let trip = viewModel.currentTrip {
                let shareTrip = { self.shareTrip() }
                ShareTripSheet(trip: trip, onShare: shareTrip)
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    /// Count of unclaimed participants in the trip
    private var unclaimedParticipantCount: Int {
        trip.participants.filter { !$0.isClaimed }.count
    }
    
    /// Whether the trip has any unclaimed participants
    private var hasUnclaimedParticipants: Bool {
        unclaimedParticipantCount > 0
    }
    
    /// Build accessibility label for a participant
    private func buildAccessibilityLabel(for participant: User) -> String {
        var label = participant.name
        
        if !participant.isClaimed {
            label += ", placeholder participant"
        } else if participant.id == viewModel.currentUser.id {
            label += ", you"
        }
        
        if !participant.email.isEmpty {
            label += ", email: \(participant.email)"
        }
        
        return label
    }
    
    /// Share trip with others to join
    private func shareTrip() {
        let shareLink = viewModel.generateShareLink()
        
        let shareMessage = """
        Join our trip '\(trip.name)' in Travel Split!
        
        • \(trip.participants.count) participants (\(unclaimedParticipantCount) unclaimed)
        • \(trip.expenses.count) expenses
        
        Use this link to join and claim your placeholder:
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
}

// MARK: - Supporting Views

/// Row view for displaying a participant
struct ParticipantRowView: View {
    let participant: User
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            // Profile image or initial
            ZStack {
                Circle()
                    .fill(participant.isClaimed ? Color.accentColor.opacity(0.2) : Color.orange.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Text(String(participant.name.prefix(1)))
                    .font(.headline)
                    .foregroundColor(participant.isClaimed ? .accentColor : .orange)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(participant.name)
                        .font(.headline)
                    
                    // Show a badge if user is a placeholder or current user
                    if !participant.isClaimed {
                        ParticipantBadge(text: "Placeholder", color: .orange)
                    } else if isCurrentUser {
                        ParticipantBadge(text: "You", color: .blue)
                    }
                }
                
                if !participant.email.isEmpty {
                    Text(participant.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .contentShape(Rectangle())
    }
}

/// Badge for displaying participant status
struct ParticipantBadge: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

// MARK: - Share Trip Sheet

/// Simplified share sheet with a focus on claiming placeholders
struct ShareTripSheet: View {
    let trip: Trip
    let onShare: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Invite friends to join this trip")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    Image(systemName: "person.badge.plus.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)
                        .accessibilityHidden(true)
                    
                    Text("Share Trip Invite")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("When people join with your invite link, they can claim placeholder participants you've already added.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Button(action: {
                    onShare()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Invite Link")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .accessibilityHint("Opens sharing options to send the invite link")
                
                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("Share Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
} 