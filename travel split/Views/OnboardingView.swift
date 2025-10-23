//
//  OnboardingView.swift
//  EquiSplit
//
//  Minimalistic onboarding explaining app layout and basic features
//

import SwiftUI

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @EnvironmentObject var languageManager: LanguageManager

    let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "person.3.fill",
            title: "onboarding_groups_title",
            description: "onboarding_groups_description",
            color: .blue
        ),
        OnboardingPage(
            icon: "dollarsign.circle.fill",
            title: "onboarding_expenses_title",
            description: "onboarding_expenses_description",
            color: .green
        ),
        OnboardingPage(
            icon: "arrow.left.arrow.right.circle.fill",
            title: "onboarding_balances_title",
            description: "onboarding_balances_description",
            color: .orange
        )
    ]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    pages[currentPage].color.opacity(0.15),
                    Color(UIColor.systemBackground)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    Button("skip".localized) {
                        completeOnboarding()
                    }
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding()
                }

                Spacer()

                // Page content
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        OnboardingPageView(page: pages[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .indexViewStyle(.page(backgroundDisplayMode: .always))

                Spacer()

                // Bottom actions
                VStack(spacing: 16) {
                    if currentPage == pages.count - 1 {
                        // Get Started button on last page
                        Button(action: completeOnboarding) {
                            Text("get_started".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                    } else {
                        // Next button
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                            HapticManager.shared.lightImpact()
                        }) {
                            Text("next".localized)
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.accentColor)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .forceRTL()
    }

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        withAnimation {
            isPresented = false
        }
        HapticManager.shared.success()
    }
}

struct OnboardingPage {
    let icon: String
    let title: String
    let description: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @EnvironmentObject var languageManager: LanguageManager

    var body: some View {
        VStack(spacing: 32) {
            // Icon
            Image(systemName: page.icon)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding()

            VStack(spacing: 16) {
                // Title
                Text(page.title.localized)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                    .rtlAwareAlignment(.center)

                // Description
                Text(page.description.localized)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .rtlAwareAlignment(.center)
            }
        }
        .padding()
    }
}

// Preview
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(isPresented: .constant(true))
            .environmentObject(LanguageManager.shared)
    }
}
