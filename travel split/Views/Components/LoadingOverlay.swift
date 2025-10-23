//
//  LoadingOverlay.swift
//  EquiSplit
//
//  Reusable loading overlay component
//

import SwiftUI

/// A reusable loading overlay view with customizable message
struct LoadingOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)

                Text(message.localized)
                    .font(.subheadline)
                    .foregroundColor(.white)
            }
            .padding(24)
            .background(Color(.systemGray6).opacity(0.95))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

/// Loading indicator for use within cards/sections
struct InlineLoadingIndicator: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())

            Text(message.localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}

/// Shimmer effect for skeleton loading
struct ShimmerView: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geometry in
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(0.3),
                    Color.gray.opacity(0.1),
                    Color.gray.opacity(0.3)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: geometry.size.width * 2)
            .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
        }
    }
}

/// Skeleton placeholder for trip row
struct TripRowSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Trip name placeholder
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 20)
                .frame(maxWidth: 200)
                .overlay(ShimmerView())
                .clipShape(RoundedRectangle(cornerRadius: 4))

            HStack {
                // Participants count placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 100, height: 16)
                    .overlay(ShimmerView())
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Spacer()

                // Balance placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 16)
                    .overlay(ShimmerView())
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.vertical, 12)
    }
}
