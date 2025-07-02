//
//  ParticipantsViews.swift
//  EquiSplit
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
    @State private var showingEditNameSheet = false
    @State private var editingName = ""
    
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            VStack {
                List {
                    // People section
                    Section(header: Text("people_in_this_group".localized)) {
                        ForEach(trip.participants) { participant in
                            ParticipantRowView(
                                participant: participant,
                                isCurrentUser: isCurrentUser(participant)
                            )
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(buildAccessibilityLabel(for: participant))
                            .contextMenu {
                                if isCurrentUser(participant) {
                                    // Edit name option for current user
                                    Button {
                                        editingName = participant.name
                                        showingEditNameSheet = true
                                    } label: {
                                        Label("edit_name".localized, systemImage: "pencil")
                                    }
                                } else {
                                    // Remove option for other participants
                                    Button(role: .destructive) {
                                        participantToRemove = participant
                                        handleRemoveParticipant(participant)
                                    } label: {
                                        Label("remove_participant".localized, systemImage: "person.badge.minus")
                                    }
                                }
                                
                                // Share option if participant is unclaimed
                                if !participant.isClaimed {
                                    Button {
                                        shareTrip()
                                    } label: {
                                        Label("share_invite_link".localized, systemImage: "square.and.arrow.up")
                                    }
                                }
                            }
                            .listRowBackground(Color(UIColor.secondarySystemGroupedBackground))
                            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                            .contentShape(Rectangle())
                            .accessibilityHint("long_press_for_options".localized)
                        }
                    }
                    
                    // Invite section - only shown if there are unclaimed participants
                    if hasUnclaimedParticipants {
                        Section {
                            Button(action: { shareTrip() }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                        .foregroundColor(.accentColor)
                                    Text("invite_people_to_claim".localized)
                                        .foregroundColor(.primary)
                                }
                            }
                            .accessibilityHint("share_group_to_claim".localized)
                        } footer: { 
                            Text(unclaimedParticipantsMessage)
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
                                Text("add_participant".localized)
                                    .foregroundColor(.primary)
                            }
                        }
                        .accessibilityHint("add_new_participant_hint".localized)
                    
                        Text("add_participant_tip".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                }
                .listStyle(InsetGroupedListStyle())
                .environment(\.defaultMinListRowHeight, 64)
            }
        }
        .alert("cannot_remove_participant".localized, isPresented: $showingBalanceWarning) {
            Button("ok".localized, role: .cancel) {
                participantToRemove = nil
            }
        } message: {
            if let participant = participantToRemove {
                Text("participant_has_balance".localized(with: participant.name))
            } else {
                Text("participants_with_balances_cannot_remove".localized)
            }
        }
        .confirmationDialog(
            "remove_participant".localized,
            isPresented: $showingRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("remove".localized, role: .destructive) {
                if let participant = participantToRemove {
                    // This will be handled by viewModel.removeParticipantFromCurrentTrip
                    let _ = viewModel.removeParticipantFromCurrentTrip(participant)
                    participantToRemove = nil
                }
            }
            
            Button("cancel".localized, role: .cancel) {
                participantToRemove = nil
            }
        } message: {
            if let participant = participantToRemove {
                Text("are_you_sure_remove_participant".localized(with: participant.name))
            } else {
                Text("are_you_sure_remove_this_participant".localized)
            }
        }
        .sheet(isPresented: $showingEditNameSheet) {
            EditNameSheet(
                currentName: editingName,
                onSave: { newName in
                    updateCurrentUserName(newName)
                    showingEditNameSheet = false
                },
                onCancel: {
                    showingEditNameSheet = false
                }
            )
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
    
    /// Formatted message for unclaimed participants
    private var unclaimedParticipantsMessage: String {
        let participantWord = unclaimedParticipantCount == 1 ? "participant".localized : "participants".localized
        return "unclaimed_participants_message".localized(with: "\(unclaimedParticipantCount)", participantWord)
    }
    
    /// Build accessibility label for a participant
    private func buildAccessibilityLabel(for participant: User) -> String {
        var label = participant.name
        
        if !participant.isClaimed {
            label += ", \("placeholder_participant".localized)"
        } else if isCurrentUser(participant) {
            label += ", \("you".localized)"
        }
        
        if !participant.email.isEmpty {
            label += ", email: \(participant.email)"
        }
        
        return label
    }
    
    /// Share trip with others to join
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
    
    /// Update the current user's name in this specific trip only
    private func updateCurrentUserName(_ newName: String) {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Get the current trip
        guard var currentTrip = viewModel.currentTrip else {
            print("Error: No current trip to update participant name")
            return
        }
        
        // Find the current user's participant entry in this trip
        let currentUserId = viewModel.currentUser.id
        
        // Look for the participant by ID or by claimedByUserId
        if let participantIndex = currentTrip.participants.firstIndex(where: { 
            $0.id == currentUserId || $0.claimedByUserId == currentUserId 
        }) {
            // Update the participant's name in this trip only
            var updatedParticipant = currentTrip.participants[participantIndex]
            updatedParticipant.name = trimmedName
            
            // Update the participant in the trip
            currentTrip.participants[participantIndex] = updatedParticipant
            
            // Update the trip immediately in the view model (this updates the UI instantly)
            viewModel.updateTrip(currentTrip)
            
            print("Updated participant name to '\(trimmedName)' in trip '\(currentTrip.name)' only")
        } else {
            print("Error: Current user not found as participant in trip")
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
            
            VStack(alignment: languageAwareHorizontalAlignment, spacing: 4) {
                HStack {
                    Text(participant.name)
                        .font(.headline)
                        .rtlAwareAlignment()
                    
                    // Show a badge if user is a placeholder or current user
                    if !participant.isClaimed {
                        ParticipantBadge(text: "placeholder".localized, color: .orange)
                    } else if isCurrentUser {
                        ParticipantBadge(text: "you".localized, color: .blue)
                    }
                }
                
                if !participant.email.isEmpty {
                    Text(participant.email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment()
                }
            }
            
            Spacer()
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

/// Sheet for editing the current user's name in the current group only
struct EditNameSheet: View {
    let currentName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var newName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    // Language manager for RTL support
    @EnvironmentObject var languageManager: LanguageManager
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("your_name".localized)) {
                    TextField("enter_your_name".localized, text: $newName)
                        .focused($isTextFieldFocused)
                        .autocapitalization(.words)
                        .disableAutocorrection(false)
                        .safeRTLTextField()
                        .accessibilityLabel("your_name".localized)
                }
                
                Section {
                    Text("update_name_in_group_only".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .rtlAwareAlignment()
                }
            }
            .navigationTitle("edit_name_title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("save".localized) {
                        onSave(newName)
                    }
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                newName = currentName
                isTextFieldFocused = true
            }
        }
        .stableLocalized()
    }
}