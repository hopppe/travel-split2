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
    @State private var participantToRemove: User?
    @State private var showingRemoveConfirmation = false
    @State private var showingBalanceWarning = false
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                List {
                    // People section
                    Section(header: Text("People in this group")) {
                        ForEach(trip.participants) { participant in
                            ParticipantRowView(
                                participant: participant,
                                isCurrentUser: isCurrentUser(participant)
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(buildAccessibilityLabel(for: participant))
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                // Don't show remove button for current user
                                if !isCurrentUser(participant) {
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        handleRemoveParticipant(participant)
                                    } label: {
                                        Label("Remove", systemImage: "person.badge.minus")
                                    }
                                    .tint(.red)
                                }
                            }
                            .contextMenu {
                                if !isCurrentUser(participant) {
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        handleRemoveParticipant(participant)
                                    } label: {
                                        Label("Remove Participant", systemImage: "person.badge.minus")
                                    }
                                }
                                
                                // Share option if participant is unclaimed
                                if !participant.isClaimed {
                                    Button {
                                        shareTrip()
                                    } label: {
                                        Label("Share Invite Link", systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .accessibilityHint(!isCurrentUser(participant) ? "Swipe left to remove, or long press for options" : "")
                        }
                    }
                    
                    // Invite section - only shown if there are unclaimed participants
                    if hasUnclaimedParticipants {
                        Section {
                            Button(action: { shareTrip() }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.accentColor)
                                    Text("Invite People to Claim Placeholders")
                                        .foregroundColor(.primary)
                                }
                            }
                            .accessibilityHint("Share group to let others claim placeholder participants")
                        } footer: { 
                            Text("You have \(unclaimedParticipantCount) unclaimed placeholder \(unclaimedParticipantCount == 1 ? "participant" : "participants"). Share the group link so others can join and claim these participants.")
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
                        .accessibilityHint("Add a new participant to this group")
                    
                        Text("Tip: You can add placeholder participants that others can claim when they join.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.defaultMinListRowHeight, 64)
            }
        }
        .alert("Cannot Remove Participant", isPresented: $showingBalanceWarning) {
            Button("OK", role: .cancel) {
                participantToRemove = nil
            }
        } message: {
            if let participant = participantToRemove {
                Text("\(participant.name) has an outstanding balance. Participants with balances cannot be removed until their balance is zero.")
            } else {
                Text("Participants with outstanding balances cannot be removed.")
            }
        }
        .confirmationDialog(
            "Remove Participant",
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                if let participant = participantToRemove {
                    // This will be handled by viewModel.removeParticipantFromCurrentTrip
                    let _ = viewModel.removeParticipantFromCurrentTrip(participant)
                    participantToRemove = nil
                }
            }
            
            Button("Cancel", role: .cancel) {
                participantToRemove = nil
            }
        } message: {
            if let participant = participantToRemove {
                Text("Are you sure you want to remove \(participant.name) from this group?")
            } else {
                Text("Are you sure you want to remove this participant?")
            }
        }
    }
    
    // MARK: - Helper Properties and Methods
    
    /// Checks if a participant is the current user
    private func isCurrentUser(_ participant: User) -> Bool {
        return participant.id == viewModel.currentUser.id || participant.claimedByUserId == viewModel.currentUser.id
    }
    
    /// Handle the remove participant action
    private func handleRemoveParticipant(_ participant: User) {
        // Check if participant can be removed (no outstanding balance)
        if viewModel.canRemoveParticipant(participant) {
            // Show confirmation dialog
            showingRemoveConfirmation = true
        } else {
            // Participant has balance, show warning
            showingBalanceWarning = true
        }
    }
    
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
        } else if isCurrentUser(participant) {
            label += ", you"
        }
        
        if !participant.email.isEmpty {
            label += ", email: \(participant.email)"
        }
        
        return label
    }
    
    /// Share trip with others to join
    private func shareTrip() {
        // Get the deep link URL from FirebaseService
        let deepLinkURL = FirebaseService.shared.createDeepLink(inviteCode: trip.inviteCode)
        
        // Create a simple share message with just the essentials
        let shareMessage = """
        Join my group "\(trip.name)" in Free Split!
        
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
            
            // Add a subtle indicator for non-current users
            if !isCurrentUser {
                Image(systemName: "chevron.left")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60) // Ensure minimum height for better touch target
        .contentShape(Rectangle()) // Make entire area tappable
        .background(Color.clear)
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