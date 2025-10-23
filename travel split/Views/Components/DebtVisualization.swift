//
//  DebtVisualization.swift
//  EquiSplit
//
//  Visual components for balance and debt display
//

import SwiftUI

/// Balance dashboard showing user's overall position
struct BalanceDashboard: View {
    let trip: Trip
    let viewModel: TripViewModel
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        let balance = viewModel.getUserBalanceInTrip(trip)

        // Main balance card
        VStack(spacing: 8) {
            Text("your_balance".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(trip.baseCurrencySymbol)\(abs(balance), specifier: "%.2f")")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(getBalanceColor(balance))

            Text(balance > 0 ? "you_are_owed".localized : (balance < 0 ? "you_owe".localized : "all_settled_up".localized))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func getBalanceColor(_ balance: Double) -> Color {
        if balance > 0 {
            return .green
        } else if balance < 0 {
            return .red
        } else {
            return .primary
        }
    }
}

/// Visual debt connection showing who owes whom
struct DebtConnectionView: View {
    let debt: Debt
    let currencySymbol: String
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 12) {
            // From user
            ParticipantAvatar(participant: debt.from, size: 44)

            VStack(spacing: 4) {
                Image(systemName: languageManager.isRTL ? "arrow.left" : "arrow.right")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("\(currencySymbol)\(debt.amount, specifier: "%.2f")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)

            // To user
            ParticipantAvatar(participant: debt.to, size: 44)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

/// Simplified debt view showing all balances
struct SimplifiedDebtView: View {
    let debts: [Debt]
    let trip: Trip
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(spacing: 12) {
            if debts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("all_balanced".localized)
                        .font(.headline)

                    Text("everyone_settled_up".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 32)
            } else {
                ForEach(debts) { debt in
                    DebtConnectionView(debt: debt, currencySymbol: trip.baseCurrencySymbol)
                }
            }
        }
    }
}
