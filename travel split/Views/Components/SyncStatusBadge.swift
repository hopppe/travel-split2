//
//  SyncStatusBadge.swift
//  EquiSplit
//
//  Sync status indicators for offline mode
//

import SwiftUI

enum SyncStatus {
    case synced
    case pending
    case failed

    var icon: String {
        switch self {
        case .synced:
            return "checkmark.icloud"
        case .pending:
            return "icloud.and.arrow.up"
        case .failed:
            return "exclamationmark.icloud"
        }
    }

    var color: Color {
        switch self {
        case .synced:
            return .green
        case .pending:
            return .orange
        case .failed:
            return .red
        }
    }

    var description: String {
        switch self {
        case .synced:
            return "synced"
        case .pending:
            return "pending_sync"
        case .failed:
            return "sync_failed"
        }
    }
}

/// Small sync status badge
struct SyncStatusBadge: View {
    let status: SyncStatus
    let showLabel: Bool

    init(status: SyncStatus, showLabel: Bool = false) {
        self.status = status
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.caption)
                .foregroundColor(status.color)

            if showLabel {
                Text(status.description.localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// Trip sync status indicator
extension Trip {
    func syncStatus(viewModel: TripViewModel) -> SyncStatus {
        if viewModel.pendingSync[id] != nil {
            return .pending
        }
        return .synced
    }
}
